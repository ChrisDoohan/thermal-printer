require "escpos/image"
require "chunky_png"

class ImageEditorController < ApplicationController
  def index
    @connected = Printer.new.available?
  end

  def print
    image_data = params[:image]
    if image_data.blank?
      render json: { error: "No image data" }, status: :unprocessable_entity
      return
    end

    # Strip data URL prefix ("data:image/png;base64,...")
    raw_base64 = image_data.sub(%r{\Adata:image/\w+;base64,}, "")
    png_bytes = Base64.decode64(raw_base64)

    # Write to a temp file so escpos-image can read it
    tempfile = Tempfile.new(["print", ".png"])
    tempfile.binmode
    tempfile.write(png_bytes)
    tempfile.rewind

    # Scale to printer width and ensure dimensions are multiples of 8
    png = ChunkyPNG::Image.from_file(tempfile.path)
    if png.width != 512
      new_height = (png.height * 512.0 / png.width).round
      png = png.resample_bilinear(512, new_height)
    end
    # Pad height to multiple of 8
    if png.height % 8 != 0
      padded_height = ((png.height + 7) / 8) * 8
      padded = ChunkyPNG::Image.new(512, padded_height, ChunkyPNG::Color::WHITE)
      padded.replace!(png, 0, 0)
      png = padded
    end
    scaled_path = tempfile.path + "_scaled.png"
    png.save(scaled_path)

    # Build ESC/POS raster data via escpos-image
    image = Escpos::Image.new(scaled_path, processor: "ChunkyPng")
    escpos_data = image.to_escpos

    tempfile.close!
    File.delete(scaled_path) if File.exist?(scaled_path)

    # Send to printer
    printer = Printer.new
    printer.send_raw(escpos_data)

    if params[:cut] == "true"
      printer.cut
    else
      printer.flush
    end

    render json: { message: "Image printed!" }
  rescue Printer::NotAvailable => e
    render json: { error: e.message }, status: :service_unavailable
  end
end

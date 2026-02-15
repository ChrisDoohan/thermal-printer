require "escpos/image"

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

    # Build ESC/POS raster data via escpos-image
    image = Escpos::Image.new(tempfile.path, processor: "ChunkyPng")
    escpos_data = image.to_escpos

    tempfile.close!

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

require "chunky_png"

class Content < ApplicationRecord
  has_many :prints, dependent: :destroy

  def self.find_or_create_by_body(body, content_type)
    hash = Digest::MD5.hexdigest(body)
    find_or_create_by(content_hash: hash) do |content|
      content.body = body
      content.content_type = content_type
      content.thumbnail = generate_thumbnail(body) if content_type == "image"
    end
  end

  private

  def self.generate_thumbnail(base64_body)
    png_bytes = Base64.decode64(base64_body)
    image = ChunkyPNG::Image.from_blob(png_bytes)

    # Rotate landscape images 90° CW so they display tall like portrait ones
    image = image.rotate_clockwise if image.width > image.height

    # Scale so the smaller dimension is 120px
    if image.width <= image.height
      scale = 120.0 / image.width
    else
      scale = 120.0 / image.height
    end

    new_w = (image.width * scale).round
    new_h = (image.height * scale).round
    image = image.resample_bilinear(new_w, new_h)

    Base64.strict_encode64(image.to_blob)
  end
end

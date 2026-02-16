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

    # Scale so the smaller dimension is 120px
    smaller = [image.width, image.height].min
    scale = 120.0 / smaller

    new_w = (image.width * scale).round
    new_h = (image.height * scale).round
    image = image.resample_bilinear(new_w, new_h)

    Base64.strict_encode64(image.to_blob)
  end
end

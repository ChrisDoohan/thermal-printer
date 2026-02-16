class Content < ApplicationRecord
  has_many :prints, dependent: :destroy

  def self.find_or_create_by_body(body, content_type)
    hash = Digest::MD5.hexdigest(body)
    find_or_create_by(content_hash: hash) do |content|
      content.body = body
      content.content_type = content_type
    end
  end
end

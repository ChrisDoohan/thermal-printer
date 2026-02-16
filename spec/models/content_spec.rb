require 'rails_helper'

RSpec.describe Content, type: :model do
  describe "associations" do
    it "has many prints" do
      content = Content.create!(body: "<p>hi</p>", content_type: "text", content_hash: "abc")
      print1 = content.prints.create!(username: "chris")
      print2 = content.prints.create!(username: "bro")
      expect(content.prints).to contain_exactly(print1, print2)
    end

    it "destroys prints when destroyed" do
      content = Content.create!(body: "<p>hi</p>", content_type: "text", content_hash: "abc")
      content.prints.create!(username: "chris")
      expect { content.destroy }.to change(Print, :count).by(-1)
    end
  end

  describe ".find_or_create_by_body" do
    it "creates a new content record with MD5 hash" do
      content = Content.find_or_create_by_body("<p>hello</p>", "text")
      expect(content).to be_persisted
      expect(content.body).to eq("<p>hello</p>")
      expect(content.content_type).to eq("text")
      expect(content.content_hash).to eq(Digest::MD5.hexdigest("<p>hello</p>"))
    end

    it "returns existing content for identical body" do
      first = Content.find_or_create_by_body("<p>hello</p>", "text")
      second = Content.find_or_create_by_body("<p>hello</p>", "text")
      expect(second.id).to eq(first.id)
      expect(Content.count).to eq(1)
    end

    it "creates separate records for different bodies" do
      Content.find_or_create_by_body("<p>hello</p>", "text")
      Content.find_or_create_by_body("<p>goodbye</p>", "text")
      expect(Content.count).to eq(2)
    end

    it "does not generate a thumbnail for text content" do
      content = Content.find_or_create_by_body("<p>hello</p>", "text")
      expect(content.thumbnail).to be_nil
    end

    context "with image content" do
      let(:portrait_image) do
        img = ChunkyPNG::Image.new(560, 800, ChunkyPNG::Color::BLACK)
        Base64.strict_encode64(img.to_blob)
      end

      let(:landscape_image) do
        img = ChunkyPNG::Image.new(800, 560, ChunkyPNG::Color::BLACK)
        Base64.strict_encode64(img.to_blob)
      end

      it "generates a thumbnail for image content" do
        content = Content.find_or_create_by_body(portrait_image, "image")
        expect(content.thumbnail).to be_present
      end

      it "scales portrait thumbnails so width is 120px" do
        content = Content.find_or_create_by_body(portrait_image, "image")
        thumb = ChunkyPNG::Image.from_blob(Base64.decode64(content.thumbnail))
        expect(thumb.width).to eq(120)
        expect(thumb.height).to be > 120
      end

      it "scales landscape thumbnails so height is 120px" do
        content = Content.find_or_create_by_body(landscape_image, "image")
        thumb = ChunkyPNG::Image.from_blob(Base64.decode64(content.thumbnail))
        expect(thumb.height).to eq(120)
        expect(thumb.width).to be > 120
      end

      it "handles square images" do
        img = ChunkyPNG::Image.new(560, 560, ChunkyPNG::Color::WHITE)
        b64 = Base64.strict_encode64(img.to_blob)
        content = Content.find_or_create_by_body(b64, "image")
        thumb = ChunkyPNG::Image.from_blob(Base64.decode64(content.thumbnail))
        expect(thumb.width).to eq(120)
        expect(thumb.height).to eq(120)
      end
    end
  end
end

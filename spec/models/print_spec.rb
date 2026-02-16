require 'rails_helper'

RSpec.describe Print, type: :model do
  describe "associations" do
    it "belongs to a content" do
      content = Content.create!(body: "<p>hi</p>", content_type: "text", content_hash: "abc")
      print = content.prints.create!(username: "chris")
      expect(print.content).to eq(content)
    end

    it "requires a content" do
      print = Print.new(username: "chris")
      expect(print).not_to be_valid
    end
  end
end

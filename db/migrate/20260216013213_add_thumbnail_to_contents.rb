class AddThumbnailToContents < ActiveRecord::Migration[8.1]
  def change
    add_column :contents, :thumbnail, :text
  end
end

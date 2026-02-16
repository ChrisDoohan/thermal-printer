class CreateContents < ActiveRecord::Migration[8.1]
  def change
    create_table :contents do |t|
      t.text :body
      t.string :content_type
      t.string :content_hash

      t.timestamps
    end

    add_index :contents, :content_hash, unique: true
  end
end

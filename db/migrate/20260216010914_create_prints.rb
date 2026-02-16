class CreatePrints < ActiveRecord::Migration[8.1]
  def change
    create_table :prints do |t|
      t.references :content, null: false, foreign_key: true
      t.string :username

      t.timestamps
    end
  end
end

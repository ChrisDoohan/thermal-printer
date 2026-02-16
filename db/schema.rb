# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_16_013213) do
  create_table "contents", force: :cascade do |t|
    t.text "body"
    t.string "content_hash"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.text "thumbnail"
    t.datetime "updated_at", null: false
    t.index ["content_hash"], name: "index_contents_on_content_hash", unique: true
  end

  create_table "prints", force: :cascade do |t|
    t.integer "content_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["content_id"], name: "index_prints_on_content_id"
  end

  add_foreign_key "prints", "contents"
end

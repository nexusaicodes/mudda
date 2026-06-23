class DropTags < ActiveRecord::Migration[8.2]
  def change
    drop_table "filters_tags", id: false do |t|
      t.uuid "filter_id", null: false
      t.uuid "tag_id", null: false
      t.index ["filter_id"], name: "index_filters_tags_on_filter_id"
      t.index ["tag_id"], name: "index_filters_tags_on_tag_id"
    end

    drop_table "taggings", id: :uuid do |t|
      t.uuid "account_id", null: false
      t.uuid "card_id", null: false
      t.datetime "created_at", null: false
      t.uuid "tag_id", null: false
      t.datetime "updated_at", null: false
      t.index ["account_id"], name: "index_taggings_on_account_id"
      t.index ["card_id", "tag_id"], name: "index_taggings_on_card_id_and_tag_id", unique: true
      t.index ["tag_id"], name: "index_taggings_on_tag_id"
    end

    drop_table "tags", id: :uuid do |t|
      t.uuid "account_id", null: false
      t.datetime "created_at", null: false
      t.string "title"
      t.datetime "updated_at", null: false
      t.index ["account_id", "title"], name: "index_tags_on_account_id_and_title", unique: true
    end
  end
end

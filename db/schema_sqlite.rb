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

ActiveRecord::Schema[8.2].define(version: 2026_08_28_000000) do
  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", limit: 255, null: false
    t.datetime "updated_at", null: false
  end

  create_table "action_pack_passkeys", force: :cascade do |t|
    t.string "aaguid", limit: 255
    t.boolean "backed_up"
    t.datetime "created_at", null: false
    t.string "credential_id", limit: 255, null: false
    t.bigint "holder_id", null: false
    t.string "holder_type", limit: 255, null: false
    t.string "name", limit: 255
    t.binary "public_key", null: false
    t.integer "sign_count", default: 0, null: false
    t.text "transports", limit: 65535
    t.datetime "updated_at", null: false
    t.index ["credential_id"], name: "index_action_pack_passkeys_on_credential_id", unique: true
    t.index ["holder_type", "holder_id"], name: "index_action_pack_passkeys_on_holder_type_and_holder_id"
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body", limit: 4294967295
    t.datetime "created_at", null: false
    t.string "name", limit: 255, null: false
    t.bigint "record_id", null: false
    t.string "record_type", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 255, null: false
    t.bigint "record_id", null: false
    t.string "record_type", limit: 255, null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum", limit: 255
    t.string "content_type", limit: 255
    t.datetime "created_at", null: false
    t.string "filename", limit: 255, null: false
    t.string "key", limit: 255, null: false
    t.text "metadata", limit: 65535
    t.string "service_name", limit: 255, null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", limit: 255, null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "boards", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "cards_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.string "name", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_boards_on_account_id"
    t.index ["creator_id"], name: "index_boards_on_creator_id"
  end

  create_table "boards_filters", id: false, force: :cascade do |t|
    t.bigint "board_id", null: false
    t.bigint "filter_id", null: false
    t.index ["board_id"], name: "index_boards_filters_on_board_id"
    t.index ["filter_id"], name: "index_boards_filters_on_filter_id"
  end

  create_table "cards", force: :cascade do |t|
    t.bigint "board_id", null: false
    t.bigint "column_id", null: false
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.date "due_on"
    t.boolean "golden", default: false, null: false
    t.datetime "last_active_at", null: false
    t.bigint "number", null: false
    t.string "title", limit: 255
    t.datetime "updated_at", null: false
    t.index ["board_id", "last_active_at"], name: "index_cards_on_board_id_and_last_active_at"
    t.index ["board_id", "number"], name: "index_cards_on_board_id_and_number", unique: true
    t.index ["column_id"], name: "index_cards_on_column_id"
    t.index ["creator_id"], name: "index_cards_on_creator_id"
  end

  create_table "columns", force: :cascade do |t|
    t.bigint "board_id", null: false
    t.string "color", limit: 255, null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 255, null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["board_id", "position"], name: "index_columns_on_board_id_and_position"
  end

  create_table "events", force: :cascade do |t|
    t.string "action", limit: 255, null: false
    t.bigint "board_id", null: false
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.bigint "eventable_id", null: false
    t.string "eventable_type", limit: 255, null: false
    t.json "particulars", default: -> { "json_object()" }
    t.datetime "updated_at", null: false
    t.index ["board_id", "action", "created_at"], name: "index_events_on_board_id_and_action_and_created_at"
    t.index ["creator_id"], name: "index_events_on_creator_id"
    t.index ["eventable_type", "eventable_id"], name: "index_events_on_eventable"
  end

  create_table "filters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.json "fields", default: -> { "json_object()" }, null: false
    t.string "params_digest", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id", "params_digest"], name: "index_filters_on_creator_id_and_params_digest", unique: true
  end

  create_table "notes", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_notes_on_card_id"
    t.index ["creator_id"], name: "index_notes_on_creator_id"
  end

  create_table "search_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "terms", limit: 2000, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "terms"], name: "index_search_queries_on_user_id_and_terms"
    t.index ["user_id", "updated_at"], name: "index_search_queries_on_user_id_and_updated_at", unique: true
  end

  create_table "search_records", force: :cascade do |t|
    t.bigint "board_id", null: false
    t.bigint "card_id", null: false
    t.text "content", limit: 65535
    t.datetime "created_at", null: false
    t.bigint "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["card_id"], name: "index_search_records_on_card_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address", limit: 255
    t.string "kind", limit: 255, default: "browser", null: false
    t.string "label", limit: 255
    t.datetime "updated_at", null: false
    t.string "user_agent", limit: 4096
    t.bigint "user_id", null: false
    t.index ["user_id", "kind"], name: "index_sessions_on_user_id_and_kind"
  end

  create_table "steps", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.boolean "completed", default: false, null: false
    t.text "content", limit: 65535, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id", "completed"], name: "index_steps_on_card_id_and_completed"
  end

  create_table "user_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "timezone_name", limit: 255
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_user_settings_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email_address", limit: 255, null: false
    t.string "name", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end
  execute "CREATE VIRTUAL TABLE search_records_fts USING fts5(\n        title,\n        content,\n        tokenize='porter'\n      )"

end

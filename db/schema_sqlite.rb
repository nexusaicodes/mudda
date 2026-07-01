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

ActiveRecord::Schema[8.2].define(version: 2026_07_01_000000) do
  create_table "account_cancellations", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "initiated_by_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_cancellations_on_account_id", unique: true
  end

  create_table "account_external_id_sequences", id: :uuid, force: :cascade do |t|
    t.bigint "value", default: 0, null: false
    t.index ["value"], name: "index_account_external_id_sequences_on_value", unique: true
  end


  create_table "accounts", id: :uuid, force: :cascade do |t|
    t.bigint "cards_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "external_account_id"
    t.string "name", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["external_account_id"], name: "index_accounts_on_external_account_id", unique: true
  end

  create_table "action_pack_passkeys", id: :uuid, force: :cascade do |t|
    t.string "aaguid", limit: 255
    t.boolean "backed_up"
    t.datetime "created_at", null: false
    t.string "credential_id", limit: 255, null: false
    t.uuid "holder_id", null: false
    t.string "holder_type", limit: 255, null: false
    t.string "name", limit: 255
    t.binary "public_key", null: false
    t.integer "sign_count", default: 0, null: false
    t.text "transports", limit: 65535
    t.datetime "updated_at", null: false
    t.index ["credential_id"], name: "index_action_pack_passkeys_on_credential_id", unique: true
    t.index ["holder_type", "holder_id"], name: "index_action_pack_passkeys_on_holder_type_and_holder_id"
  end

  create_table "action_text_rich_texts", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.text "body", limit: 4294967295
    t.datetime "created_at", null: false
    t.string "name", limit: 255, null: false
    t.uuid "record_id", null: false
    t.string "record_type", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_action_text_rich_texts_on_account_id"
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 255, null: false
    t.uuid "record_id", null: false
    t.string "record_type", limit: 255, null: false
    t.index ["account_id"], name: "index_active_storage_attachments_on_account_id"
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", limit: 255
    t.string "content_type", limit: 255
    t.datetime "created_at", null: false
    t.string "filename", limit: 255, null: false
    t.string "key", limit: 255, null: false
    t.text "metadata", limit: 65535
    t.string "service_name", limit: 255, null: false
    t.index ["account_id"], name: "index_active_storage_blobs_on_account_id"
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "blob_id", null: false
    t.string "variation_digest", limit: 255, null: false
    t.index ["account_id"], name: "index_active_storage_variant_records_on_account_id"
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "boards", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.string "name", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_boards_on_account_id"
    t.index ["creator_id"], name: "index_boards_on_creator_id"
  end

  create_table "boards_filters", id: false, force: :cascade do |t|
    t.uuid "board_id", null: false
    t.uuid "filter_id", null: false
    t.index ["board_id"], name: "index_boards_filters_on_board_id"
    t.index ["filter_id"], name: "index_boards_filters_on_filter_id"
  end

  create_table "card_goldnesses", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_card_goldnesses_on_account_id"
    t.index ["card_id"], name: "index_card_goldnesses_on_card_id", unique: true
  end

  create_table "cards", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.uuid "column_id", null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.date "due_on"
    t.datetime "last_active_at", null: false
    t.bigint "number", null: false
    t.string "status", limit: 255, default: "drafted", null: false
    t.string "title", limit: 255
    t.datetime "updated_at", null: false
    t.index ["account_id", "last_active_at", "status"], name: "index_cards_on_account_id_and_last_active_at_and_status"
    t.index ["account_id", "number"], name: "index_cards_on_account_id_and_number", unique: true
    t.index ["board_id"], name: "index_cards_on_board_id"
    t.index ["column_id"], name: "index_cards_on_column_id"
  end

  create_table "columns", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.string "color", limit: 255, null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 255, null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_columns_on_account_id"
    t.index ["board_id", "position"], name: "index_columns_on_board_id_and_position"
    t.index ["board_id"], name: "index_columns_on_board_id"
  end

  create_table "events", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "action", limit: 255, null: false
    t.uuid "board_id", null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.uuid "eventable_id", null: false
    t.string "eventable_type", limit: 255, null: false
    t.json "particulars", default: -> { "json_object()" }
    t.datetime "updated_at", null: false
    t.index ["account_id", "action"], name: "index_events_on_account_id_and_action"
    t.index ["board_id", "action", "created_at"], name: "index_events_on_board_id_and_action_and_created_at"
    t.index ["board_id"], name: "index_events_on_board_id"
    t.index ["creator_id"], name: "index_events_on_creator_id"
    t.index ["eventable_type", "eventable_id"], name: "index_events_on_eventable"
  end


  create_table "filters", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.json "fields", default: -> { "json_object()" }, null: false
    t.string "params_digest", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_filters_on_account_id"
    t.index ["creator_id", "params_digest"], name: "index_filters_on_creator_id_and_params_digest", unique: true
  end

  create_table "identities", id: :uuid, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", limit: 255, null: false
    t.boolean "staff", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_identities_on_email_address", unique: true
  end

  create_table "magic_links", id: :uuid, force: :cascade do |t|
    t.string "code", limit: 255, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.uuid "identity_id"
    t.integer "purpose", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_magic_links_on_code", unique: true
    t.index ["expires_at"], name: "index_magic_links_on_expires_at"
    t.index ["identity_id"], name: "index_magic_links_on_identity_id"
  end

  create_table "notes", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_notes_on_account_id"
    t.index ["card_id"], name: "index_notes_on_card_id"
  end

  create_table "search_queries", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.string "terms", limit: 2000, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_search_queries_on_account_id"
    t.index ["user_id", "terms"], name: "index_search_queries_on_user_id_and_terms"
    t.index ["user_id", "updated_at"], name: "index_search_queries_on_user_id_and_updated_at", unique: true
    t.index ["user_id"], name: "index_search_queries_on_user_id"
  end

  create_table "search_records", force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "board_id", null: false
    t.uuid "card_id", null: false
    t.text "content", limit: 65535
    t.datetime "created_at", null: false
    t.uuid "searchable_id", null: false
    t.string "searchable_type", limit: 255, null: false
    t.string "title", limit: 255
    t.index ["account_id"], name: "index_search_records_on_account_id"
    t.index ["searchable_type", "searchable_id"], name: "index_search_records_on_searchable_type_and_searchable_id", unique: true
  end

  create_table "sessions", id: :uuid, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "identity_id", null: false
    t.string "ip_address", limit: 255
    t.datetime "updated_at", null: false
    t.string "user_agent", limit: 4096
    t.index ["identity_id"], name: "index_sessions_on_identity_id"
  end

  create_table "steps", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "card_id", null: false
    t.boolean "completed", default: false, null: false
    t.text "content", limit: 65535, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_steps_on_account_id"
    t.index ["card_id", "completed"], name: "index_steps_on_card_id_and_completed"
    t.index ["card_id"], name: "index_steps_on_card_id"
  end

  create_table "storage_entries", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "blob_id"
    t.uuid "board_id"
    t.datetime "created_at", null: false
    t.bigint "delta", null: false
    t.string "operation", limit: 255, null: false
    t.uuid "recordable_id"
    t.string "recordable_type", limit: 255
    t.string "request_id", limit: 255
    t.uuid "user_id"
    t.index ["account_id"], name: "index_storage_entries_on_account_id"
    t.index ["blob_id"], name: "index_storage_entries_on_blob_id"
    t.index ["board_id"], name: "index_storage_entries_on_board_id"
    t.index ["recordable_type", "recordable_id"], name: "index_storage_entries_on_recordable"
    t.index ["request_id"], name: "index_storage_entries_on_request_id"
    t.index ["user_id"], name: "index_storage_entries_on_user_id"
  end

  create_table "storage_totals", id: :uuid, force: :cascade do |t|
    t.bigint "bytes_stored", default: 0, null: false
    t.datetime "created_at", null: false
    t.uuid "last_entry_id"
    t.uuid "owner_id", null: false
    t.string "owner_type", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_storage_totals_on_owner_type_and_owner_id", unique: true
  end

  create_table "user_settings", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.datetime "created_at", null: false
    t.string "timezone_name", limit: 255
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["account_id"], name: "index_user_settings_on_account_id"
    t.index ["user_id"], name: "index_user_settings_on_user_id"
    t.index ["user_id"], name: "index_user_settings_on_user_id_and_bundle_email_frequency"
  end

  create_table "users", id: :uuid, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.uuid "identity_id"
    t.string "name", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["account_id", "identity_id"], name: "index_users_on_account_id_and_identity_id", unique: true
    t.index ["account_id"], name: "index_users_on_account_id_and_role"
    t.index ["identity_id"], name: "index_users_on_identity_id"
  end
  execute "CREATE VIRTUAL TABLE search_records_fts USING fts5(\n        title,\n        content,\n        tokenize='porter'\n      )"

end

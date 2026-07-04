class DropStorageAccounting < ActiveRecord::Migration[8.2]
  def change
    drop_table :storage_entries, id: :uuid do |t|
      t.uuid     :account_id, null: false
      t.uuid     :blob_id
      t.uuid     :board_id
      t.datetime :created_at, null: false
      t.bigint   :delta, null: false
      t.string   :operation, limit: 255, null: false
      t.uuid     :recordable_id
      t.string   :recordable_type, limit: 255
      t.string   :request_id, limit: 255
      t.uuid     :user_id
      t.index [ :account_id ], name: "index_storage_entries_on_account_id"
      t.index [ :blob_id ], name: "index_storage_entries_on_blob_id"
      t.index [ :board_id ], name: "index_storage_entries_on_board_id"
      t.index [ :recordable_type, :recordable_id ], name: "index_storage_entries_on_recordable"
      t.index [ :request_id ], name: "index_storage_entries_on_request_id"
      t.index [ :user_id ], name: "index_storage_entries_on_user_id"
    end

    drop_table :storage_totals, id: :uuid do |t|
      t.bigint   :bytes_stored, default: 0, null: false
      t.datetime :created_at, null: false
      t.uuid     :last_entry_id
      t.uuid     :owner_id, null: false
      t.string   :owner_type, limit: 255, null: false
      t.datetime :updated_at, null: false
      t.index [ :owner_type, :owner_id ], name: "index_storage_totals_on_owner_type_and_owner_id", unique: true
    end
  end
end

class DropMagicLinks < ActiveRecord::Migration[8.2]
  def change
    drop_table :magic_links, id: :uuid do |t|
      t.string   :code, limit: 255, null: false
      t.datetime :created_at, null: false
      t.datetime :expires_at, null: false
      t.uuid     :identity_id
      t.integer  :purpose, null: false
      t.datetime :updated_at, null: false
      t.index [ :code ], name: "index_magic_links_on_code", unique: true
      t.index [ :expires_at ], name: "index_magic_links_on_expires_at"
      t.index [ :identity_id ], name: "index_magic_links_on_identity_id"
    end
  end
end

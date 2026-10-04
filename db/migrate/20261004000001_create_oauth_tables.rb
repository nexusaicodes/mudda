# Doorkeeper's tables, with PKCE and refresh-token rotation, plus the link from a session to the
# OAuth client it was authorized for (see Session::Oauth).
class CreateOauthTables < ActiveRecord::Migration[8.2]
  def change
    create_table :oauth_applications do |t|
      t.string :name, limit: 255, null: false
      t.string :uid, limit: 255, null: false
      t.string :secret, limit: 255, null: false
      t.text :redirect_uri, limit: 65535, null: false
      t.string :scopes, limit: 255, null: false, default: ""
      t.boolean :confidential, null: false, default: true
      t.timestamps
      t.index :uid, unique: true
    end

    create_table :oauth_access_grants do |t|
      t.bigint :resource_owner_id, null: false
      t.bigint :application_id, null: false
      t.string :token, limit: 255, null: false
      t.integer :expires_in, null: false
      t.text :redirect_uri, limit: 65535, null: false
      t.string :scopes, limit: 255, null: false, default: ""
      t.string :code_challenge, limit: 255
      t.string :code_challenge_method, limit: 255
      t.datetime :created_at, null: false
      t.datetime :revoked_at
      t.index :token, unique: true
      t.index :resource_owner_id
      t.index :application_id
    end

    create_table :oauth_access_tokens do |t|
      t.bigint :resource_owner_id
      t.bigint :application_id, null: false
      t.string :token, limit: 255, null: false
      t.string :refresh_token, limit: 255
      t.integer :expires_in
      t.string :scopes, limit: 255
      t.datetime :created_at, null: false
      t.datetime :revoked_at
      t.string :previous_refresh_token, limit: 255, null: false, default: ""
      t.index :token, unique: true
      t.index :refresh_token, unique: true
      t.index :resource_owner_id
      t.index :application_id
    end

    add_column :sessions, :oauth_application_id, :bigint
    add_index :sessions, :oauth_application_id
  end
end

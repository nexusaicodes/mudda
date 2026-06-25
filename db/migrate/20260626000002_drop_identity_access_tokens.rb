class DropIdentityAccessTokens < ActiveRecord::Migration[8.2]
  def up
    drop_table :identity_access_tokens, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

class AddTokenScopesAndAgentNames < ActiveRecord::Migration[8.2]
  def up
    add_column :sessions, :scopes, :string, limit: 255
    add_column :events, :agent_name, :string, limit: 255

    # Tokens minted before scopes existed could do everything, and keep that.
    execute "UPDATE sessions SET scopes = 'read write delete' WHERE kind = 'token'"
  end

  def down
    remove_column :sessions, :scopes
    remove_column :events, :agent_name
  end
end

class AddLabelToSessions < ActiveRecord::Migration[8.2]
  def change
    add_column :sessions, :label, :string, limit: 255
  end
end

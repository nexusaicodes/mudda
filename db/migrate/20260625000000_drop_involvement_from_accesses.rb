class DropInvolvementFromAccesses < ActiveRecord::Migration[8.2]
  def change
    remove_column :accesses, :involvement, :string, default: "access_only", null: false
  end
end

# A single-person deployment has nothing to call its account; the owner's name is the one shown.
class RemoveNameFromAccounts < ActiveRecord::Migration[8.2]
  def change
    remove_column :accounts, :name, :string, limit: 255, null: false, default: ""
  end
end

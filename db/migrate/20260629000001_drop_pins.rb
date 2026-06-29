class DropPins < ActiveRecord::Migration[8.2]
  def up
    drop_table :pins, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

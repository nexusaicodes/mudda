# A pinned card sorts to the top of its lane.
class RenameGoldenToPinnedOnCards < ActiveRecord::Migration[8.2]
  def change
    rename_column :cards, :golden, :pinned
  end
end

# Searches were remembered for a history nothing showed, and users were marked verified by a
# sign-up flow that is gone. Neither was read.
class DropSearchHistoryAndUserVerification < ActiveRecord::Migration[8.2]
  def change
    drop_table :search_queries do |t|
      t.bigint :user_id, null: false
      t.string :terms, limit: 2000, null: false
      t.timestamps
      t.index %i[ user_id terms ]
      t.index %i[ user_id updated_at ], unique: true
    end

    remove_column :users, :verified_at, :datetime
  end
end

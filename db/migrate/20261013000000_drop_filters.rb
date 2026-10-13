# A filter is read from the query string for each request and never stored.
class DropFilters < ActiveRecord::Migration[8.2]
  def change
    drop_table :boards_filters, id: false do |t|
      t.bigint :board_id, null: false, index: true
      t.bigint :filter_id, null: false, index: true
    end

    drop_table :filters do |t|
      t.bigint :creator_id, null: false
      t.json :fields, default: -> { "json_object()" }, null: false
      t.string :params_digest, limit: 255, null: false
      t.timestamps
      t.index %i[ creator_id params_digest ], unique: true
    end
  end
end

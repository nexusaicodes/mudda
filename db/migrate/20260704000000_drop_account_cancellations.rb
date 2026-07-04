class DropAccountCancellations < ActiveRecord::Migration[8.2]
  def change
    drop_table :account_cancellations, id: :uuid do |t|
      t.uuid     :account_id, null: false
      t.datetime :created_at, null: false
      t.uuid     :initiated_by_id, null: false
      t.datetime :updated_at, null: false
      t.index [ :account_id ], name: "index_account_cancellations_on_account_id", unique: true
    end
  end
end

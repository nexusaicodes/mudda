# What a hosting platform keeps in step with the board: the plan it last pushed and where to
# upgrade from it, where and how to sign the board's webhooks, the sequence number that orders its
# messages, when the owner's name last changed, and the outbox of events waiting to be sent.
class AddPlatformSync < ActiveRecord::Migration[8.2]
  def change
    change_table :accounts do |t|
      t.string :plan
      t.string :upgrade_url, limit: 2048
      t.string :webhook_url, limit: 2048
      t.string :webhook_secret
      t.bigint :platform_seq, null: false, default: 0
    end

    add_column :users, :name_changed_at, :datetime, precision: 6

    create_table :webhook_deliveries do |t|
      t.string :event_id, null: false
      t.string :kind, null: false
      t.text :payload, null: false
      t.integer :attempts, null: false, default: 0
      t.datetime :next_attempt_at
      t.datetime :delivered_at
      t.string :last_error

      t.timestamps

      t.index :event_id, unique: true
      t.index :next_attempt_at
    end
  end
end

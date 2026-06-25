class DropWebhooks < ActiveRecord::Migration[8.2]
  def change
    drop_table "webhook_deliveries", id: :uuid do |t|
      t.uuid "account_id", null: false
      t.datetime "created_at", null: false
      t.uuid "event_id", null: false
      t.text "request"
      t.text "response"
      t.string "state", null: false
      t.datetime "updated_at", null: false
      t.uuid "webhook_id", null: false
      t.index ["account_id"], name: "index_webhook_deliveries_on_account_id"
      t.index ["created_at"], name: "index_webhook_deliveries_on_created_at"
      t.index ["event_id"], name: "index_webhook_deliveries_on_event_id"
      t.index ["webhook_id"], name: "index_webhook_deliveries_on_webhook_id"
    end

    drop_table "webhook_delinquency_trackers", id: :uuid do |t|
      t.uuid "account_id", null: false
      t.integer "consecutive_failures_count", default: 0
      t.datetime "created_at", null: false
      t.datetime "first_failure_at"
      t.datetime "updated_at", null: false
      t.uuid "webhook_id", null: false
      t.index ["account_id"], name: "index_webhook_delinquency_trackers_on_account_id"
      t.index ["webhook_id"], name: "index_webhook_delinquency_trackers_on_webhook_id"
    end

    drop_table "webhooks", id: :uuid do |t|
      t.uuid "account_id", null: false
      t.boolean "active", default: true, null: false
      t.uuid "board_id", null: false
      t.datetime "created_at", null: false
      t.string "name"
      t.string "signing_secret", null: false
      t.text "subscribed_actions"
      t.datetime "updated_at", null: false
      t.text "url", null: false
      t.index ["account_id"], name: "index_webhooks_on_account_id"
      t.index ["board_id", "subscribed_actions"], name: "index_webhooks_on_board_id_and_subscribed_actions"
    end
  end
end

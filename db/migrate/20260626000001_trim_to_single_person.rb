# Collapses the schema to the single-person (solopreneur) build: comments become
# notes, and every table/column that only existed to coordinate multiple people
# or the removed social features is dropped.
class TrimToSinglePerson < ActiveRecord::Migration[8.2]
  def up
    rename_table :comments, :notes

    drop_table :mentions, if_exists: true
    drop_table :assignments, if_exists: true
    drop_table :watches, if_exists: true
    drop_table :reactions, if_exists: true
    drop_table :notifications, if_exists: true
    drop_table :notification_bundles, if_exists: true
    drop_table :push_subscriptions, if_exists: true
    drop_table :accesses, if_exists: true
    drop_table :board_publications, if_exists: true
    drop_table :account_join_codes, if_exists: true
    drop_table :assignees_filters, if_exists: true
    drop_table :assigners_filters, if_exists: true
    drop_table :creators_filters, if_exists: true

    remove_column :users, :role, if_exists: true
    remove_column :boards, :all_access, if_exists: true
    remove_column :user_settings, :bundle_email_frequency, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

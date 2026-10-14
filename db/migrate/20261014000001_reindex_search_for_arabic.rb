# Rebuilds the full-text index so every row holds the normalized text that Arabic queries
# match against.
class ReindexSearchForArabic < ActiveRecord::Migration[8.2]
  def up
    execute "DELETE FROM search_records_fts"
    execute "DELETE FROM search_records"

    SearchReindexJob.perform_now
  end

  def down
  end
end

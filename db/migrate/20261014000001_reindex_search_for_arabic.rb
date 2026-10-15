# Rewrites every search row with the normalized text that Arabic queries match against.
# Reindexing upserts in place, so a record the job skips keeps its existing row.
class ReindexSearchForArabic < ActiveRecord::Migration[8.2]
  def up
    SearchReindexJob.perform_now
  end

  def down
  end
end

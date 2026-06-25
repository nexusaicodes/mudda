namespace :search do
  desc "Reindex all cards and notes in the search index"
  task reindex: :environment do
    puts "Clearing search records..."
    ActiveRecord::Base.connection.execute("DELETE FROM search_records")
    ActiveRecord::Base.connection.execute("DELETE FROM search_records_fts")

    puts "Reindexing cards and notes..."
    SearchReindexJob.perform_now

    puts "Done! Reindexed #{Card.count} cards and #{Note.count} notes."
  end
end

namespace :search do
  desc "Reindex all cards and notes in the search index"
  task reindex: :environment do
    puts "Clearing search records..."
    ActiveRecord::Base.connection.execute("DELETE FROM search_records")
    ActiveRecord::Base.connection.execute("DELETE FROM search_records_fts")

    puts "Reindexing cards and notes..."
    job = SearchReindexJob.new
    job.perform_now
    stats = job.stats

    puts "Indexed #{stats[:indexed]}, skipped #{stats[:skipped]} with oversized rich text, failed #{stats[:failed]}."
    abort "Search reindex incomplete: #{stats[:failed]} records failed (see the error.reported log lines)." if stats[:failed].positive?
  end
end

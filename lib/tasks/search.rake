namespace :search do
  desc "Reindex all cards and comments in the search index"
  task reindex: :environment do
    puts "Clearing search records..."
    ActiveRecord::Base.connection.execute("DELETE FROM search_records")
    ActiveRecord::Base.connection.execute("DELETE FROM search_records_fts")

    puts "Reindexing cards..."
    Card.includes(:rich_text_description).find_each(&:reindex)

    puts "Reindexing comments..."
    Comment.includes(:rich_text_body, :card).find_each(&:reindex)

    puts "Done! Reindexed #{Card.count} cards and #{Comment.count} comments."
  end
end

require "test_helper"

class SearchReindexJobTest < ActiveJob::TestCase
  test "reindexes cards and notes after their search records are nuked" do
    card = cards(:logo)
    note = notes(:logo_1)

    card.reindex
    note.reindex

    card_shard = Search::Record
    note_shard = Search::Record

    assert card_shard.exists?(searchable_type: "Card", searchable_id: card.id)
    assert note_shard.exists?(searchable_type: "Note", searchable_id: note.id)

    card_shard.delete_all
    note_shard.delete_all unless note_shard == card_shard

    assert_not card_shard.exists?(searchable_type: "Card", searchable_id: card.id)
    assert_not note_shard.exists?(searchable_type: "Note", searchable_id: note.id)

    SearchReindexJob.perform_now

    assert card_shard.exists?(searchable_type: "Card", searchable_id: card.id)
    assert note_shard.exists?(searchable_type: "Note", searchable_id: note.id)
  end

  test "skips records whose rich text exceeds rich_text_limit" do
    Current.account = accounts(:"37s")
    Current.session = Session.new(user: users(:david))

    big_card = boards(:writebook).cards.create!(
      creator: users(:david),
      title: "too big to index",
      status: :published, due_on: 1.week.from_now,
      description: "x" * 5_000
    )

    nuke_search_records

    SearchReindexJob.perform_now(rich_text_limit: 1_000)

    shard = Search::Record
    assert_not shard.exists?(searchable_type: "Card", searchable_id: big_card.id)
  end

  test "does not index drafted cards or their notes" do
    Current.account = accounts(:"37s")
    Current.session = Session.new(user: users(:david))

    card = boards(:writebook).cards.create!(
      creator: users(:david),
      title: "will be drafted",
      status: :published, due_on: 1.week.from_now
    )
    note = card.notes.create!(creator: users(:david), body: "on a card that will be drafted")
    card.update!(status: :drafted)

    nuke_search_records

    SearchReindexJob.perform_now

    shard = Search::Record
    assert_not shard.exists?(searchable_type: "Card", searchable_id: card.id)
    assert_not shard.exists?(searchable_type: "Note", searchable_id: note.id)
  end

  private
    def nuke_search_records
      ActiveRecord::Base.connection.execute("DELETE FROM search_records")
      ActiveRecord::Base.connection.execute("DELETE FROM search_records_fts")
    end
end

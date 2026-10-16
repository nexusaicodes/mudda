require "test_helper"

class Note::SearchableTest < ActiveSupport::TestCase
  include SearchTestHelper

  setup do
    @card = @board.cards.create!(title: "Test Card", due_on: 1.week.from_now, creator: @user)
  end

  test "a note whose indexing fails is still saved, and the failure reported" do
    Search::Record.stubs(:create!).raises(ActiveRecord::StatementInvalid, "database is locked")

    note = nil
    assert_error_reported(ActiveRecord::StatementInvalid) do
      note = @card.notes.create!(body: "unindexed", creator: @user)
    end
    assert note.persisted?
  end

  test "a note whose audit event fails is still saved, and the failure reported" do
    Event.any_instance.stubs(:save!).raises(ActiveRecord::RecordInvalid)

    note = nil
    assert_error_reported(ActiveRecord::RecordInvalid) do
      note = @card.notes.create!(body: "unaudited", creator: @user)
    end
    assert note.persisted?
  end

  test "note search" do
    search_record_class = Search::Record
    # Note is indexed on create
    note = @card.notes.create!(body: "searchable note text", creator: @user)
    record = search_record_class.find_by(searchable_type: "Note", searchable_id: note.id)
    assert_not_nil record

    # Note is updated in index
    note.update!(body: "updated text")
    record = search_record_class.find_by(searchable_type: "Note", searchable_id: note.id)
    assert_match /updat/, record.content

    # Note is removed from index on destroy
    note_id = note.id
    search_record_id = record.id

    # Verify FTS entry exists before deletion
    fts_entry = record.search_records_fts
    assert_not_nil fts_entry, "FTS entry should exist before note deletion"

    note.destroy
    record = search_record_class.find_by(searchable_type: "Note", searchable_id: note_id)
    assert_nil record

    # Verify FTS entry is also deleted
    fts_count = Search::Record::SQLite::Fts.where(rowid: search_record_id).count
    assert_equal 0, fts_count, "FTS entry should be deleted after note deletion"

    # Finding cards via note search
    card_with_note = @board.cards.create!(title: "Card One", due_on: 1.week.from_now, creator: @user)
    card_with_note.notes.create!(body: "unique searchable phrase", creator: @user)
    card_without_note = @board.cards.create!(title: "Card Two", due_on: 1.week.from_now, creator: @user)
    results = Card.mentioning("searchable", user: @user)
    assert_includes results, card_with_note
    assert_not_includes results, card_without_note

    # Note stores its parent card, and reaches the board through it
    new_note = @card.notes.create!(body: "test note", creator: @user)
    record = search_record_class.find_by(searchable_type: "Note", searchable_id: new_note.id)
    assert_equal @card.id, record.card_id
  end

  # A record reaches its board through its card, so a moved card's notes stay findable after
  # the board it left is gone, with nothing to reindex.
  test "a moved card's notes are still found once the board it left is deleted" do
    old_board = @board
    card = old_board.cards.create!(title: "Wandering card", due_on: 1.week.from_now, creator: @user)
    card.notes.create!(body: "peregrination", creator: @user)

    card.update!(board: Board.create!(name: "New Home", account: @account, creator: @user))
    old_board.destroy!

    assert_includes Card.mentioning("peregrination", user: @user), card
  end
end

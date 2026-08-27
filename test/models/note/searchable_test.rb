require "test_helper"

class Note::SearchableTest < ActiveSupport::TestCase
  include SearchTestHelper

  setup do
    @card = @board.cards.create!(title: "Test Card", status: "published", due_on: 1.week.from_now, creator: @user)
  end

  test "searchable? returns true for notes on published cards" do
    note = @card.notes.create!(body: "test note", creator: @user)
    assert note.searchable?
  end

  test "searchable? returns false for notes on draft cards" do
    draft_card = @board.cards.create!(title: "Draft Card", status: "drafted", creator: @user)
    note = draft_card.notes.build(body: "test note", creator: @user)
    assert_not note.searchable?
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

    # For SQLite, verify FTS entry exists before deletion
    if search_record_class.connection.adapter_name == "SQLite"
      fts_entry = record.search_records_fts
      assert_not_nil fts_entry, "FTS entry should exist before note deletion"
    end

    note.destroy
    record = search_record_class.find_by(searchable_type: "Note", searchable_id: note_id)
    assert_nil record

    # For SQLite, verify FTS entry is also deleted
    if search_record_class.connection.adapter_name == "SQLite"
      fts_count = Search::Record::SQLite::Fts.where(rowid: search_record_id).count
      assert_equal 0, fts_count, "FTS entry should be deleted after note deletion"
    end

    # Finding cards via note search
    card_with_note = @board.cards.create!(title: "Card One", status: "published", due_on: 1.week.from_now, creator: @user)
    card_with_note.notes.create!(body: "unique searchable phrase", creator: @user)
    card_without_note = @board.cards.create!(title: "Card Two", status: "published", due_on: 1.week.from_now, creator: @user)
    results = Card.mentioning("searchable", user: @user)
    assert_includes results, card_with_note
    assert_not_includes results, card_without_note

    # Note stores parent card_id and board_id
    new_note = @card.notes.create!(body: "test note", creator: @user)
    record = search_record_class.find_by(searchable_type: "Note", searchable_id: new_note.id)
    assert_equal @card.id, record.card_id
    assert_equal @board.id, record.board_id
  end
end

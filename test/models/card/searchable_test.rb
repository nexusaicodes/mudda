require "test_helper"

class Card::SearchableTest < ActiveSupport::TestCase
  include SearchTestHelper

  test "card search" do
    # Searching by title
    card = @board.cards.create!(title: "layout is broken", due_on: 1.week.from_now, creator: @user)
    results = Card.mentioning("layout", user: @user)
    assert_includes results, card

    # Searching by note
    card_with_note = @board.cards.create!(title: "Some card", due_on: 1.week.from_now, creator: @user)
    card_with_note.notes.create!(body: "overflowing text", creator: @user)
    results = Card.mentioning("overflowing", user: @user)
    assert_includes results, card_with_note

    # Sanitizing search query
    card_broken = @board.cards.create!(title: "broken layout", due_on: 1.week.from_now, creator: @user)
    results = Card.mentioning("broken \"", user: @user)
    assert_includes results, card_broken

    # Empty query returns no results
    assert_empty Card.mentioning("\"", user: @user)

    # Searching spans every board in the account
    other_board = Board.create!(name: "Other Board", account: @account, creator: @user)
    card_in_board = @board.cards.create!(title: "searchable content", due_on: 1.week.from_now, creator: @user)
    card_in_other_board = other_board.cards.create!(title: "searchable content", due_on: 1.week.from_now, creator: @user)
    results = Card.mentioning("searchable", user: @user)
    assert_includes results, card_in_board
    assert_includes results, card_in_other_board
  end

  test "search content is truncated to a reasonable limit" do
    search_record_class = Search::Record

    # Create a card with unreasonably long content
    long_content = "asdf " * Searchable::SEARCH_CONTENT_LIMIT
    card = @board.cards.create!(title: "Card with long description", due_on: 1.week.from_now, creator: @user)
    card.description = ActionText::Content.new(long_content)
    card.save!

    # Check if was indexed
    results = Card.mentioning("asdf", user: @user)
    assert_includes results, card

    # Check the content length was within the limit
    search_record = search_record_class.find_by(searchable_type: "Card", searchable_id: card.id)
    assert search_record.content.bytesize <= Searchable::SEARCH_CONTENT_LIMIT
  end

  test "deleting card removes search record and FTS entry" do
    search_record_class = Search::Record
    card = @board.cards.create!(title: "Card to delete", due_on: 1.week.from_now, creator: @user)

    # Verify search record exists
    search_record = search_record_class.find_by(searchable_type: "Card", searchable_id: card.id)
    assert_not_nil search_record, "Search record should exist after card creation"

    # For SQLite, verify FTS entry exists
    if search_record_class.connection.adapter_name == "SQLite"
      fts_entry = search_record.search_records_fts
      assert_not_nil fts_entry, "FTS entry should exist"
      assert_equal card.title, fts_entry.title
    end

    # Delete the card
    card.destroy

    # Verify search record is deleted
    search_record = search_record_class.find_by(searchable_type: "Card", searchable_id: card.id)
    assert_nil search_record, "Search record should be deleted after card deletion"

    # For SQLite, verify FTS entry is deleted
    if search_record_class.connection.adapter_name == "SQLite"
      fts_count = Search::Record::SQLite::Fts.where(rowid: card.id).count
      assert_equal 0, fts_count, "FTS entry should be deleted"
    end
  end

  # Every card is indexed the moment it exists, so a card is findable as soon as it is real.
  test "a card is indexed on create" do
    card = @board.cards.create!(title: "Findable immediately", creator: @user, due_on: 1.week.from_now)

    assert_not_nil Search::Record.find_by(searchable_type: "Card", searchable_id: card.id)
    assert_includes Card.mentioning("Findable", user: @user), card
  end
end

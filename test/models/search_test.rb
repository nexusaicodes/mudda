require "test_helper"

class SearchTest < ActiveSupport::TestCase
  include SearchTestHelper

  test "search" do
    # Search cards and notes
    card = @board.cards.create!(title: "layout design", creator: @user, due_on: 1.week.from_now)
    note_card = @board.cards.create!(title: "Some card", creator: @user, due_on: 1.week.from_now)
    note_card.notes.create!(body: "overflowing text", creator: @user)

    results = Search::Record.search("layout", user: @user)
    assert results.find { |it| it.card_id == card.id }

    results = Search::Record.search("overflowing", user: @user)
    assert results.find { |it| it.card_id == note_card.id && it.searchable_type == "Note" }
  end

  test "search for hyphenated strings" do
    card = @board.cards.create!(title: "BC3-IOS-1D8B", creator: @user, due_on: 1.week.from_now)

    results = Search::Record.search("BC3-IOS-1D8B", user: @user)
    assert results.find { |it| it.card_id == card.id }
  end

  test "search matches Arabic regardless of harakat, hamza and the article" do
    greeting = @board.cards.create!(title: "مَرْحَباً بالعالم", creator: @user, due_on: 1.week.from_now)
    book = @board.cards.create!(title: "قرأت الكتاب", creator: @user, due_on: 1.week.from_now)
    prefixed = @board.cards.create!(title: "بالكتاب", creator: @user, due_on: 1.week.from_now)
    name = @board.cards.create!(title: "أحمد", creator: @user, due_on: 1.week.from_now)

    assert_includes card_ids_for("مرحبا"), greeting.id
    assert_includes card_ids_for("كتاب"), book.id
    assert_includes card_ids_for("كتاب"), prefixed.id
    assert_includes card_ids_for("احمد"), name.id
  end

  test "search still stems English" do
    card = @board.cards.create!(title: "running tests", creator: @user, due_on: 1.week.from_now)

    assert_includes card_ids_for("run"), card.id
  end

  test "search highlights the stored Arabic title" do
    @board.cards.create!(title: "قرأت الكتابَ", creator: @user, due_on: 1.week.from_now)

    record = Search::Record.search("كتاب", user: @user).first
    assert_includes record.card_title, "#{Search::Highlighter::OPENING_MARK}الكتابَ</mark>"
  end

  private
    def card_ids_for(terms)
      Search::Record.search(terms, user: @user).map(&:card_id)
    end
end

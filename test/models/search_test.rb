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
end

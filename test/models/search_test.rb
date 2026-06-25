require "test_helper"

class SearchTest < ActiveSupport::TestCase
  include SearchTestHelper

  test "search" do
    # Search cards and notes
    card = @board.cards.create!(title: "layout design", creator: @user, status: "published")
    note_card = @board.cards.create!(title: "Some card", creator: @user, status: "published")
    note_card.notes.create!(body: "overflowing text", creator: @user)

    results = Search::Record.for(@user.account_id).search("layout", user: @user)
    assert results.find { |it| it.card_id == card.id }

    results = Search::Record.for(@user.account_id).search("overflowing", user: @user)
    assert results.find { |it| it.card_id == note_card.id && it.searchable_type == "Note" }

    # Drafted cards are excluded from search results
    drafted_card = @board.cards.create!(title: "drafted searchable content", creator: @user, status: "drafted")
    results = Search::Record.for(@user.account_id).search("drafted", user: @user)
    assert_not results.find { |it| it.card_id == drafted_card.id }
  end

  test "search for hyphenated strings" do
    card = @board.cards.create!(title: "BC3-IOS-1D8B", creator: @user, status: "published")

    results = Search::Record.for(@user.account_id).search("BC3-IOS-1D8B", user: @user)
    assert results.find { |it| it.card_id == card.id }
  end
end

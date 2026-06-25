require "test_helper"

class CardTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "create assigns a number to the card" do
    user = users(:david)
    board = boards(:writebook)
    account = board.account
    card = nil

    assert_difference -> { account.reload.cards_count }, +1 do
      card = Card.create!(title: "Test", board: board, creator: user)
    end

    assert_equal account.reload.cards_count, card.number
  end

  test "closed" do
    assert_equal [ cards(:shipping) ], Card.closed
  end

  test "open" do
    assert_equal cards(:logo, :layout, :text, :buy_domain).to_set, accounts("37s").cards.open.to_set
    assert_equal cards(:radio, :paycheck, :unfinished_thoughts).to_set, accounts("initech").cards.open.to_set
  end

  test "in board" do
    new_board = Board.create! name: "New Board", creator: users(:david)
    assert_equal cards(:logo, :shipping, :layout, :text, :buy_domain).to_set, Card.where(board: boards(:writebook)).to_set
    assert_empty Card.where(board: new_board)
  end

  test "for published cards, it should set the default title 'Untitiled' when not provided" do
    card = boards(:writebook).cards.create! due_on: 1.week.from_now
    assert_nil card.title

    card.publish
    assert_equal "Untitled", card.reload.title
  end

  test "send back to triage when moved to a new board" do
    cards(:logo).update! column: columns(:writebook_doing)

    assert_changes -> { cards(:logo).reload.triaged? }, from: true, to: false do
      cards(:logo).update! board: boards(:private)
    end
  end

  test "move cards to a different board" do
    card = cards(:logo)
    old_board = card.board
    new_board = boards(:private)

    card.notes.create!(body: "Sensitive information", creator: users(:david))

    card_events_on_old_board = card.events.where(board: old_board)
    note_events_on_old_board = Event.where(board: old_board, eventable: card.notes)

    assert card_events_on_old_board.exists?
    assert note_events_on_old_board.exists?

    card.move_to(new_board)

    assert_equal new_board, card.reload.board

    card_events_on_new_board = card.events.where(board: new_board)
    note_events_on_new_board = Event.where(board: new_board, eventable: card.notes)

    assert_empty card_events_on_old_board
    assert_empty note_events_on_old_board
    assert card_events_on_new_board.exists?
    assert note_events_on_new_board.exists?
    assert card_events_on_new_board.find_by(action: "card_board_changed")
  end

  test "a card is filled if it has either the title or the description set" do
    assert Card.new(title: "Some title").filled?
    assert Card.new(description: "Some description").filled?

    assert_not Card.new.filled?
  end
end

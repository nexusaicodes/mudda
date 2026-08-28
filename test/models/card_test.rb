require "test_helper"

class CardTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "create assigns a number to the card" do
    user = users(:david)
    board = boards(:writebook)
    card = nil

    assert_difference -> { board.reload.cards_count }, +1 do
      card = Card.create!(title: "Test", board: board, creator: user, due_on: 1.week.from_now)
    end

    assert_equal board.reload.cards_count, card.number
  end

  test "assigns distinct numbers when the account counter is stale in memory" do
    board = boards(:writebook)

    # Two in-memory copies of the same account row, both holding the same
    # cards_count — the state two concurrent card creates would race from.
    board_a = Account.find(board.account_id).boards.find(board.id)
    board_b = Account.find(board.account_id).boards.find(board.id)

    card_a = board_a.cards.create!(title: "A", creator: users(:kevin), due_on: 1.week.from_now)
    card_b = board_b.cards.create!(title: "B", creator: users(:kevin), due_on: 1.week.from_now)

    assert_not_equal card_a.number, card_b.number
    assert_equal card_a.number + 1, card_b.number
  end

  test "closed" do
    assert_equal [ cards(:shipping) ], Card.closed
  end

  test "by_due_date orders upcoming soonest-first with overdue cards at the bottom" do
    board = boards(:writebook)
    board.cards.destroy_all

    far      = board.cards.create! title: "Far",      creator: users(:david), due_on: 10.days.from_now
    soon     = board.cards.create! title: "Soon",     creator: users(:david), due_on: 2.days.from_now
    overdue  = board.cards.create! title: "Overdue",  creator: users(:david), due_on: 3.days.ago
    later    = board.cards.create! title: "Later",    creator: users(:david), due_on: 5.days.from_now

    assert_equal [ soon, later, far, overdue ], board.cards.by_due_date.to_a
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

  test "a card without a title of its own gets a default one" do
    card = boards(:writebook).cards.create! due_on: 1.week.from_now

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

    card.update!(board: new_board)

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

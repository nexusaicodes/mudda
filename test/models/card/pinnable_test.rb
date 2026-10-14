require "test_helper"

class Card::PinnableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @pinned, @unpinned = cards(:logo), cards(:text)
    @pinned.pin
  end

  test "check whether a card is pinned" do
    assert @pinned.pinned?
    assert_not @unpinned.pinned?
  end

  test "promote and demote from pinned" do
    assert_changes -> { @unpinned.reload.pinned? }, to: true do
      @unpinned.pin
    end

    assert_changes -> { @pinned.reload.pinned? }, to: false do
      @pinned.unpin
    end
  end

  test "scopes" do
    assert_includes Card.pinned, @pinned
    assert_not_includes Card.pinned, @unpinned
  end

  test "with_pinned_first orders pinned first" do
    ordered = Card.where(id: [ @pinned.id, @unpinned.id ]).with_pinned_first
    assert_equal [ @pinned, @unpinned ], ordered.to_a

    # Preserves base ordering as subordering
    @unpinned.pin
    base_ordered = Card.where(id: [ @pinned.id, @unpinned.id ]).order(id: :desc).to_a
    with_pinned = Card.where(id: [ @pinned.id, @unpinned.id ]).order(id: :desc).with_pinned_first.to_a
    assert_equal base_ordered, with_pinned
  end

  test "pinning a card touches both the card and the board" do
    board = @unpinned.board

    card_updated_at = @unpinned.updated_at
    board_updated_at = board.updated_at

    travel 1.minute do
      @unpinned.pin
    end

    assert @unpinned.reload.updated_at > card_updated_at
    assert board.reload.updated_at > board_updated_at
  end
end

require "test_helper"

class Account::CardLimitedTest < ActiveSupport::TestCase
  setup do
    Current.user = users(:david)
    @account = accounts("37s")
    @board = boards(:writebook)
  end

  test "without MUDDA_CARD_LIMIT there is no ceiling, but cards are still counted" do
    with_env("MUDDA_CARD_LIMIT" => nil) do
      assert_not @account.card_limited?
      assert_not @account.card_limit_reached?

      assert_difference -> { @account.reload.cards_created_count }, 1 do
        create_card
      end
    end
  end

  test "a value that isn't a whole number is no ceiling" do
    %w[ abc -5 1.5 ].each do |value|
      with_env("MUDDA_CARD_LIMIT" => value) { assert_nil @account.card_limit, value }
    end

    with_env("MUDDA_CARD_LIMIT" => "08") { assert_equal 8, @account.card_limit }
  end

  test "a card past the ceiling is refused with the reason on the card" do
    @account.update_column :cards_created_count, 3

    with_env("MUDDA_CARD_LIMIT" => "4") do
      create_card
      assert @account.reload.card_limit_reached?

      card = nil
      assert_no_difference -> { Card.count } do
        card = @board.cards.create(title: "One too many", due_on: 1.week.from_now)
      end

      assert_includes card.errors[:base], "This account has used all 4 of its cards"
      assert_raises(ActiveRecord::RecordInvalid) { create_card }
      assert_equal 4, @account.reload.cards_created_count
    end
  end

  test "deleting a card doesn't give its slot back" do
    @account.update_column :cards_created_count, 4

    with_env("MUDDA_CARD_LIMIT" => "5") do
      create_card.destroy!

      assert_equal 5, @account.reload.cards_created_count
      assert @account.card_limit_reached?
    end
  end

  test "moving a card to another board doesn't count as a new card" do
    @account.update_column :cards_created_count, 5

    with_env("MUDDA_CARD_LIMIT" => "5") do
      cards(:logo).update!(board: boards(:private))

      assert_equal 5, @account.reload.cards_created_count
    end
  end

  test "a failed card doesn't use a slot" do
    with_env("MUDDA_CARD_LIMIT" => "100") do
      assert_no_difference -> { @account.reload.cards_created_count } do
        @board.cards.create(title: "No due date")
      end
    end
  end

  test "the warning starts near the ceiling" do
    with_env("MUDDA_CARD_LIMIT" => "100") do
      @account.cards_created_count = 89
      assert_not @account.card_limit_near?

      @account.cards_created_count = 90
      assert @account.card_limit_near?
      assert_equal 10, @account.cards_remaining
    end
  end

  test "claiming a slot leaves the stored count on the account" do
    @account.update_column :cards_created_count, 7
    Account.where(id: @account.id).update_all(cards_created_count: 9)

    with_env("MUDDA_CARD_LIMIT" => "9") do
      assert_not @account.claim_card_slot
      assert_equal 9, @account.cards_created_count
      assert_not @account.changed?
    end
  end

  private
    def create_card
      @board.cards.create!(title: "Counted", due_on: 1.week.from_now)
    end
end

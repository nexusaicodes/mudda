require "test_helper"

class Account::CardLimitedTest < ActiveSupport::TestCase
  setup do
    Current.user = users(:david)
    @account = accounts("37s")
    @board = boards(:writebook)
  end

  test "a self-hosted board has no plan and no ceiling, but cards are still counted" do
    with_env("MUDDA_PLATFORM_KEYS" => nil) do
      @account.update_columns plan: "free"

      assert_nil @account.current_plan
      assert_not @account.card_limited?

      assert_difference -> { @account.reload.cards_created_count }, 1 do
        create_card
      end
    end
  end

  test "a hosted board is free until the platform names a plan" do
    trusting_the_platform do
      assert_equal "free", @account.current_plan
      assert_equal 100, @account.card_limit

      @account.update_columns plan: "premium"
      assert_equal "premium", @account.current_plan
      assert_not @account.card_limited?
    end
  end

  test "only known plans can be stored" do
    @account.plan = "enterprise"
    assert_not @account.valid?
  end

  test "a card past the ceiling is refused with the reason on the card" do
    @account.update_column :cards_created_count, 99

    on_the_free_plan do
      create_card
      assert @account.reload.card_limit_reached?

      card = nil
      assert_no_difference -> { Card.count } do
        card = @board.cards.create(title: "One too many", due_on: 1.week.from_now)
      end

      assert_includes card.errors[:base], "This account has used all 100 of its cards"
      assert_raises(ActiveRecord::RecordInvalid) { create_card }
      assert_equal 100, @account.reload.cards_created_count
    end
  end

  test "deleting a card doesn't give its slot back" do
    @account.update_column :cards_created_count, 99

    on_the_free_plan do
      create_card.destroy!

      assert_equal 100, @account.reload.cards_created_count
      assert @account.card_limit_reached?
    end
  end

  test "moving a card to another board doesn't count as a new card" do
    @account.update_column :cards_created_count, 100

    on_the_free_plan do
      cards(:logo).update!(board: boards(:private))

      assert_equal 100, @account.reload.cards_created_count
    end
  end

  test "a failed card doesn't use a slot" do
    on_the_free_plan do
      assert_no_difference -> { @account.reload.cards_created_count } do
        @board.cards.create(title: "In another board's lane", column: columns(:private_doing))
      end
    end
  end

  test "the warning starts near the ceiling" do
    on_the_free_plan do
      @account.cards_created_count = 89
      assert_not @account.card_limit_near?

      @account.cards_created_count = 90
      assert @account.card_limit_near?
      assert_equal 10, @account.cards_remaining
    end
  end

  test "claiming a slot leaves the stored count on the account" do
    @account.update_column :cards_created_count, 98
    Account.where(id: @account.id).update_all(cards_created_count: 100)

    on_the_free_plan do
      assert_not @account.claim_card_slot
      assert_equal 100, @account.cards_created_count
      assert_not @account.changed?
    end
  end

  private
    def create_card
      @board.cards.create!(title: "Counted", due_on: 1.week.from_now)
    end
end

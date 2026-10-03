require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "create" do
    assert_difference "Account.count", +1 do
      Account.create!(name: "ACME corp")
    end
  end

  test ".create_with_owner creates a new local account" do
    Current.without_account do
      account = nil

      assert_changes -> { Account.count }, +1 do
        assert_changes -> { User.count }, +1 do
          account = Account.create_with_owner(
            account: { name: "Account Create With Owner" },
            owner: { name: "David", email_address: "owner@example.com" }
          )
        end
      end

      assert account.persisted?
      assert_equal "Account Create With Owner", account.name

      owner = account.users.first
      assert_equal "David", owner.name
      assert_equal "owner@example.com", owner.email_address

      assert owner.verified?, "owner should be verified on account creation"
    end
  end

  test "cards reach the account through its boards" do
    assert_equal accounts("37s").boards.flat_map(&:cards).sort_by(&:id),
      accounts("37s").cards.order(:id).to_a
  end
end

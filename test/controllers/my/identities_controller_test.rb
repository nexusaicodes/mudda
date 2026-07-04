require "test_helper"

class My::IdentitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show as JSON" do
    identity = identities(:kevin)
    expected_count = identity.users_with_accounts.count

    untenanted do
      get my_identity_path, as: :json
      assert_response :success
      assert_equal identity.id, @response.parsed_body["id"]
      assert_equal expected_count, @response.parsed_body["accounts"].count
    end
  end

  test "show as JSON lists every account the identity belongs to" do
    identity = identities(:kevin)

    first_account = Account.create!(external_account_id: 9999981, name: "First Account")
    second_account = Account.create!(external_account_id: 9999982, name: "Second Account")
    identity.users.create!(account: first_account, name: "Kevin")
    identity.users.create!(account: second_account, name: "Kevin")

    untenanted do
      get my_identity_path, as: :json
      assert_response :success

      account_ids = @response.parsed_body["accounts"].map { |account| account["id"] }

      assert_includes account_ids, first_account.id
      assert_includes account_ids, second_account.id
    end
  end
end

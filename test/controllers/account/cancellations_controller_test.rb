require "test_helper"

class Account::CancellationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:"37s")
    @user = users(:jason)
    sign_in_as @user

    if @account.respond_to?(:subscription)
      Account.any_instance.stubs(:subscription).returns(nil)
    end
  end

  test "an owner can cancel the account" do
    assert_difference -> { Account::Cancellation.count }, 1 do
      post account_cancellation_url
    end

    assert_redirected_to session_menu_path(script_name: nil)
    assert_equal "Account deleted", flash[:notice]
    assert @account.reload.cancelled?
    assert_equal @user, @account.cancellation.initiated_by
  end

  test "cancelling an account while in single-tenant mode does nothing" do
    with_multi_tenant_mode(false) do
      assert_no_difference -> { Account::Cancellation.count } do
        post account_cancellation_url
      end

      assert_not @account.reload.cancelled?
    end
  end
end

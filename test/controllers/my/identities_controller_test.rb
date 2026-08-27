require "test_helper"

class My::IdentitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show as JSON" do
    identity = identities(:kevin)

    get my_identity_path, as: :json

    assert_response :success
    assert_equal identity.id, @response.parsed_body["id"]
  end

  test "show as JSON reports the signed-in account and user" do
    get my_identity_path, as: :json

    assert_response :success

    account = @response.parsed_body["account"]
    assert_equal accounts("37s").id, account["id"]
    assert_equal users(:kevin).id, account["user"]["id"]
    assert_not account.key?("slug"), "The account slug is gone with URL tenancy"
  end
end

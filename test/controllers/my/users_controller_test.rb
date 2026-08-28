require "test_helper"

class My::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show as JSON" do
    user = users(:kevin)

    get my_user_path, as: :json

    assert_response :success
    assert_equal user.id, @response.parsed_body["id"]
  end

  test "show as JSON reports the signed-in account and user" do
    get my_user_path, as: :json

    assert_response :success

    assert_equal users(:kevin).id, @response.parsed_body["id"]
    assert_equal users(:kevin).email_address, @response.parsed_body["email_address"]

    account = @response.parsed_body["account"]
    assert_equal accounts("37s").id, account["id"]
    assert_not account.key?("slug"), "The account slug is gone with URL tenancy"
  end
end

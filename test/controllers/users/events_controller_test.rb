require "test_helper"

class Users::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show self" do
    get user_events_path(users(:kevin))
    assert_in_body "What have you been up to?"
  end

  test "show with a valid day" do
    get user_events_path(users(:kevin), day: "2025-01-15")
    assert_response :success
  end

  test "show with an out-of-range day returns not found" do
    get user_events_path(users(:kevin), day: "2020-99-99")
    assert_response :not_found
  end

  test "show with an unparseable day returns not found" do
    get user_events_path(users(:kevin), day: "hello")
    assert_response :not_found
  end
end

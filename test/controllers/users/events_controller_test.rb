require "test_helper"

class Users::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show self" do
    get user_events_path(users(:kevin))
    assert_in_body "What have you been up to?"
  end
end

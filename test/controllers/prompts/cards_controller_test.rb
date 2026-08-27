require "test_helper"

class Prompts::CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get prompts_cards_path
    assert_response :success
  end

  # It renders a fragment explicitly, so without the guard a JSON request would be a 500
  # rather than the 406 every other browser-only endpoint answers with.
  test "the autocomplete refuses JSON" do
    get prompts_cards_path, as: :json
    assert_response :not_acceptable
  end
end

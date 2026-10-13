require "test_helper"

class CurrentLocaleTest < ActionDispatch::IntegrationTest
  test "a signed-out browser asking for Arabic gets a right-to-left page" do
    get new_session_path, headers: { "Accept-Language" => "ar-EG,ar;q=0.9,en;q=0.8" }

    assert_select "html[lang=ar][dir=rtl]"
  end

  test "an unsupported language falls back to English" do
    get new_session_path, headers: { "Accept-Language" => "fr-FR,de;q=0.5" }

    assert_select "html[lang=en][dir=ltr]"
  end

  test "the higher quality language wins" do
    get new_session_path, headers: { "Accept-Language" => "en;q=0.4,ar;q=0.9" }

    assert_select "html[lang=ar]"
  end

  test "the user's setting wins over the browser" do
    users(:kevin).settings.update!(locale: "ar")
    sign_in_as :kevin

    get user_path(users(:kevin)), headers: { "Accept-Language" => "en" }

    assert_select "html[lang=ar][dir=rtl]"
  end

  test "JSON answers in English for an Arabic user" do
    users(:kevin).settings.update!(locale: "ar")
    card = cards(:text)

    put board_card_path(card.board, card, format: :json),
      params: { due_on: nil },
      headers: bearer_headers_for(users(:kevin)).merge("Accept-Language" => "ar"), as: :json

    assert_response :unprocessable_entity
    assert_equal [ "can't be blank in Todo or Doing" ], @response.parsed_body.dig("errors", "due_on")
  end

  test "the ETag changes with the language" do
    sign_in_as :kevin

    get user_path(users(:kevin))
    english = @response.headers["ETag"]

    users(:kevin).settings.update!(locale: "ar")
    get user_path(users(:kevin))

    assert_not_equal english, @response.headers["ETag"]
  end
end

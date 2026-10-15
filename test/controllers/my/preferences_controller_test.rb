require "test_helper"

class My::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update the locale" do
    patch my_preferences_path, params: { locale: "ar" }

    assert_redirected_to user_path(users(:kevin))
    assert_equal "ar", users(:kevin).reload.locale
  end

  test "a blank locale follows the browser" do
    users(:kevin).settings.update!(locale: "ar")

    patch my_preferences_path, params: { locale: "" }

    assert_nil users(:kevin).reload.locale
  end

  test "update the theme without touching the locale" do
    users(:kevin).settings.update!(locale: "ar")

    patch my_preferences_path, params: { theme: "dark" }

    assert_equal "dark", users(:kevin).reload.theme
    assert_equal "ar", users(:kevin).locale
  end

  test "the theme is rendered on the page by the server" do
    get user_path(users(:kevin))
    assert_select "html:not([data-theme])"

    users(:kevin).settings.update!(theme: "light")
    get user_path(users(:kevin))
    assert_select "html[data-theme=light]"
  end

  test "a change of theme is not served from the cache" do
    get user_path(users(:kevin))
    etag = response.headers["ETag"]

    users(:kevin).settings.update!(theme: "dark")
    get user_path(users(:kevin)), headers: { "If-None-Match" => etag }

    assert_response :success
  end

  test "the profile marks the chosen options" do
    users(:kevin).settings.update!(theme: "dark")

    get user_path(users(:kevin))

    assert_select "button.preference-choice__option[aria-pressed=true]", text: "Dark"
    assert_select "button.preference-choice__option[aria-pressed=true]", text: "Automatic"
  end

  test "read and write as JSON" do
    get my_preferences_path, as: :json
    assert_equal({ "locale" => nil, "theme" => "auto" }, @response.parsed_body)

    patch my_preferences_path, params: { theme: "light", locale: "en" }, as: :json
    assert_response :no_content
    assert_equal [ "en", "light" ], [ users(:kevin).reload.locale, users(:kevin).theme ]
  end

  test "a body wrapped in the resource name is accepted" do
    patch my_preferences_path, params: { preferences: { theme: "dark" } }, as: :json
    assert_response :no_content
    assert_equal "dark", users(:kevin).reload.theme
  end

  test "a browser reading preferences is sent to the profile" do
    get my_preferences_path
    assert_redirected_to user_path(users(:kevin))
  end

  test "an unknown theme or locale is a 422 as JSON" do
    patch my_preferences_path, params: { theme: "sepia" }, as: :json
    assert_response :unprocessable_entity
    assert @response.parsed_body.dig("errors", "theme").present?

    patch my_preferences_path, params: { locale: "fr" }, as: :json
    assert_response :unprocessable_entity
    assert @response.parsed_body.dig("errors", "locale").present?
    assert_equal "auto", users(:kevin).reload.theme
  end
end

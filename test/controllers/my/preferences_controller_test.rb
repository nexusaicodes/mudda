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

  test "the app has one look, so pages carry no theme" do
    get user_path(users(:kevin))

    assert_select "html[data-theme]", count: 0
    assert_select "button.preference-choice__option", text: "Dark", count: 0
  end

  test "with no language chosen, the profile marks the one the browser asked for" do
    get user_path(users(:kevin)), headers: { "Accept-Language" => "ar" }

    assert_select "button.preference-choice__option", count: 2
    assert_select "button.preference-choice__option[aria-pressed=true]", text: "العربية"
  end

  test "the profile marks the chosen language over the browser's" do
    users(:kevin).settings.update!(locale: "en")

    get user_path(users(:kevin)), headers: { "Accept-Language" => "ar" }

    assert_select "button.preference-choice__option[aria-pressed=true]", text: "English"
  end

  test "read and write as JSON" do
    get my_preferences_path, as: :json
    assert_equal({ "locale" => nil }, @response.parsed_body)

    patch my_preferences_path, params: { locale: "en" }, as: :json
    assert_response :no_content
    assert_equal "en", users(:kevin).reload.locale
  end

  test "a body wrapped in the resource name is accepted" do
    patch my_preferences_path, params: { preferences: { locale: "ar" } }, as: :json
    assert_response :no_content
    assert_equal "ar", users(:kevin).reload.locale
  end

  test "a browser reading preferences is sent to the profile" do
    get my_preferences_path
    assert_redirected_to user_path(users(:kevin))
  end

  test "an unknown locale is a 422 as JSON" do
    patch my_preferences_path, params: { locale: "fr" }, as: :json
    assert_response :unprocessable_entity
    assert @response.parsed_body.dig("errors", "locale").present?
  end
end

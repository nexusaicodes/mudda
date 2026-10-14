require "test_helper"

class My::TimezonesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "the browser saves its zone" do
    put my_timezone_path, params: { timezone: { timezone_name: "America/New_York" } }

    assert_response :no_content
    assert_equal ActiveSupport::TimeZone["America/New_York"], users(:kevin).reload.timezone
  end

  test "a zone sent as JSON, flat or wrapped" do
    patch my_timezone_path, params: { timezone_name: "America/Chicago" }, as: :json
    assert_response :no_content
    assert_equal "America/Chicago", users(:kevin).reload.settings.timezone_name

    patch my_timezone_path, params: { timezone: { timezone_name: "Asia/Kolkata" } }, as: :json
    assert_response :no_content
    assert_equal "Asia/Kolkata", users(:kevin).reload.settings.timezone_name
  end

  test "a name that isn't a zone is refused, and the saved one kept" do
    users(:kevin).settings.update!(timezone_name: "Asia/Kolkata")

    patch my_timezone_path, params: { timezone_name: "Mars/Olympus_Mons" }, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "is invalid" ], @response.parsed_body.dig("errors", "timezone_name")
    assert_equal "Asia/Kolkata", users(:kevin).reload.settings.timezone_name
  end

  test "a blank or null zone clears the saved one" do
    users(:kevin).settings.update!(timezone_name: "Asia/Kolkata")

    patch my_timezone_path, params: { timezone_name: " " }, as: :json
    assert_response :no_content
    assert_nil users(:kevin).reload.settings.timezone_name

    users(:kevin).settings.update!(timezone_name: "Asia/Kolkata")

    patch my_timezone_path, params: { timezone_name: nil }, as: :json
    assert_response :no_content
    assert_nil users(:kevin).reload.settings.timezone_name
  end

  test "a request naming no zone is refused" do
    patch my_timezone_path, params: {}, as: :json

    assert_response :bad_request
    assert_equal [ "is required" ], @response.parsed_body.dig("errors", "timezone")
  end

  test "a user without settings gets them on saving a zone" do
    logout_and_sign_in_as :mike
    assert_nil User::Settings.find_by(user: users(:mike))

    patch my_timezone_path, params: { timezone_name: "Europe/Berlin" }, as: :json

    assert_response :no_content
    assert_equal "Europe/Berlin", users(:mike).reload.settings.timezone_name
  end
end

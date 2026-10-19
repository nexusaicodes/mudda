require "test_helper"

class My::TimezonesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
  end

  test "the browser saves its zone" do
    put my_timezone_path, params: { timezone: "America/New_York" }

    assert_response :no_content
    assert_equal ActiveSupport::TimeZone["America/New_York"], users(:david).reload.timezone
  end

  test "a zone sent as JSON, under the key GET /my/user reports it by" do
    patch my_timezone_path, params: { timezone: "Asia/Kolkata" }, as: :json
    assert_response :no_content

    get my_user_path(format: :json)
    reported = @response.parsed_body["timezone"]
    assert_equal "Asia/Kolkata", reported

    patch my_timezone_path, params: { timezone: reported }, as: :json
    assert_response :no_content
  end

  test "a name that isn't a zone is refused, and the saved one kept" do
    users(:david).settings.update!(timezone_name: "Asia/Kolkata")

    patch my_timezone_path, params: { timezone: "Mars/Olympus_Mons" }, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "is invalid" ], @response.parsed_body.dig("errors", "timezone")
    assert_equal "Asia/Kolkata", users(:david).reload.settings.timezone_name
  end

  test "a request naming no zone is refused" do
    [ {}, { timezone: "" }, { timezone: nil } ].each do |body|
      patch my_timezone_path, params: body, as: :json

      assert_response :bad_request
      assert_equal [ "is required" ], @response.parsed_body.dig("errors", "timezone")
    end
  end
end

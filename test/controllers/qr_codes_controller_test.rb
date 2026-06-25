require "test_helper"

class QrCodesControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    signed_token = QrCodeLink.new("https://app.mudda.do/").signed

    get qr_code_path(signed_token)

    assert_response :success
    assert_match %r{image/svg\+xml}, response.content_type
    assert_includes response.body, "<svg"
  end
end

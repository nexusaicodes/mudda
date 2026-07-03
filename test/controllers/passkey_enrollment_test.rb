require "test_helper"

class PasskeyEnrollmentTest < ActionDispatch::IntegrationTest
  test "authenticated user without a passkey is forced to enroll" do
    sign_in_without_passkey :kevin

    get root_path
    assert_redirected_to my_passkeys_path
  end

  test "authenticated user with a passkey is allowed through" do
    sign_in_as :kevin # enrolls a passkey

    get root_path
    assert_response :success
  end

  test "the passkey list itself is reachable without a passkey" do
    sign_in_without_passkey :kevin

    get my_passkeys_path
    assert_response :success
  end

  # Only full-page navigations are steered to enrollment. Background requests run instead of being
  # redirected, so nothing the layout fires on load (e.g. the timezone sync) can loop the page.
  test "turbo frame requests are not redirected to enrollment" do
    sign_in_without_passkey :kevin

    get root_path, headers: { "Turbo-Frame" => "content" }
    assert_response :success
  end

  test "prefetch requests are not redirected to enrollment" do
    sign_in_without_passkey :kevin

    get root_path, headers: { "X-Sec-Purpose" => "prefetch" }
    assert_response :success
  end

  test "non-GET requests are not redirected to enrollment" do
    sign_in_without_passkey :kevin

    patch my_timezone_path, params: { timezone_name: "America/New_York" }
    assert_response :no_content
  end

  test "JSON API requests are not redirected to enrollment" do
    sign_in_without_passkey :kevin

    get board_path(boards(:writebook)), as: :json
    assert_response :success
  end
end

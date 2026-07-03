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
end

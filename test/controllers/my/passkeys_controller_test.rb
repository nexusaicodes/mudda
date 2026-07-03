require "test_helper"

class My::PasskeysControllerTest < ActionDispatch::IntegrationTest
  include WebauthnTestHelper

  setup do
    sign_in_as :kevin
  end

  test "index" do
    get my_passkeys_path
    assert_response :success
  end

  test "register a passkey" do
    challenge = request_webauthn_challenge(purpose: "registration")

    assert_difference -> { identities(:kevin).passkeys.count }, 1 do
      post my_passkeys_path, params: build_attestation_params(challenge: challenge)
    end

    passkey = identities(:kevin).passkeys.order(created_at: :desc).first
    assert_redirected_to edit_my_passkey_path(passkey, created: true)
    assert_equal [ "internal" ], passkey.transports
  end

  test "deleting a passkey is allowed while another remains" do
    extra = identities(:kevin).passkeys.create!(
      credential_id: SecureRandom.base64(32),
      public_key: SessionTestHelper::DUMMY_PASSKEY_PUBLIC_KEY,
      sign_count: 0
    )

    assert_difference -> { identities(:kevin).passkeys.count }, -1 do
      delete my_passkey_path(extra)
    end

    assert_redirected_to my_passkeys_path
  end

  test "refuses to delete the only passkey so password sign-in can't silently reopen" do
    passkey = identities(:kevin).passkeys.sole

    assert_no_difference -> { identities(:kevin).passkeys.count } do
      delete my_passkey_path(passkey)
    end

    assert_redirected_to my_passkeys_path
  end

  test "registering the first passkey welcomes the owner and lands on home" do
    sign_in_without_passkey :kevin
    challenge = request_webauthn_challenge(purpose: "registration")

    post my_passkeys_path, params: build_attestation_params(challenge: challenge)

    assert_redirected_to landing_path
    assert flash[:welcome_letter]

    follow_redirect! # landing keeps the flash and redirects on to home
    follow_redirect! # home renders the welcome letter over the layout
    assert_select ".welcome-letter"
  end
end

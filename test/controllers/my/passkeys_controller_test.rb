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

  test "a malformed attestation is rejected with an alert instead of a 500" do
    challenge = request_webauthn_challenge(purpose: "registration")
    params = build_attestation_params(challenge: challenge)
    # A CBOR array header declaring a 2**64-1 length — decoding raises InvalidCborError.
    params[:passkey][:attestation_object] =
      Base64.urlsafe_encode64([ 0x9b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff ].pack("C*"), padding: false)

    assert_no_difference -> { identities(:kevin).passkeys.count } do
      post my_passkeys_path, params: params
    end

    assert_redirected_to my_passkeys_path
    assert_equal "That passkey couldn't be registered. Try again.", flash[:alert]
  end

  test "deleting a passkey" do
    passkey = identities(:kevin).passkeys.create!(
      credential_id: SecureRandom.base64(32),
      public_key: SessionTestHelper::DUMMY_PASSKEY_PUBLIC_KEY,
      sign_count: 0
    )

    assert_difference -> { identities(:kevin).passkeys.count }, -1 do
      delete my_passkey_path(passkey)
    end

    assert_redirected_to my_passkeys_path
  end
end

require "test_helper"

class My::PasskeyChallengesControllerTest < ActionDispatch::IntegrationTest
  test "returns a fresh challenge" do
    post my_passkey_challenge_url

    assert_response :success
    assert_not_nil response.parsed_body["challenge"]
  end

  test "returns a different challenge each time" do
    post my_passkey_challenge_url
    first_challenge = response.parsed_body["challenge"]

    post my_passkey_challenge_url
    second_challenge = response.parsed_body["challenge"]

    assert_not_equal first_challenge, second_challenge
  end

  test "uses registration challenge expiration for registration purpose" do
    post my_passkey_challenge_url, params: { purpose: "registration" }

    assert_response :success

    challenge = response.parsed_body["challenge"]
    signed_message = Base64.urlsafe_decode64(challenge)

    travel Rails.configuration.action_pack.web_authn.creation_challenge_expiration - 1.second
    assert ActionPack::WebAuthn.challenge_verifier.verified(signed_message, purpose: "registration")

    travel 2.seconds
    assert_nil ActionPack::WebAuthn.challenge_verifier.verified(signed_message, purpose: "registration")
  end

  test "uses authentication challenge expiration by default" do
    post my_passkey_challenge_url

    assert_response :success

    challenge = response.parsed_body["challenge"]
    signed_message = Base64.urlsafe_decode64(challenge)

    travel Rails.configuration.action_pack.web_authn.request_challenge_expiration - 1.second
    assert ActionPack::WebAuthn.challenge_verifier.verified(signed_message, purpose: "authentication")

    travel 2.seconds
    assert_nil ActionPack::WebAuthn.challenge_verifier.verified(signed_message, purpose: "authentication")
  end
end

# Signs messages as the hosting platform would, with a key the board trusts for the length of
# a block (see Platform::Message).
module PlatformMessageTestHelper
  PLATFORM_HOST = "board.example.com"

  def platform_key
    @platform_key ||= OpenSSL::PKey.generate_key("ED25519")
  end

  def trusting_the_platform(&)
    keys = "k1:#{Base64.strict_encode64(platform_key.raw_public_key)}"
    with_env("MUDDA_PLATFORM_KEYS" => keys, "BASE_URL" => "https://#{PLATFORM_HOST}", &)
  end

  def platform_message(kind, payload = {}, seq: 1, aud: PLATFORM_HOST, kid: "k1", key: platform_key, iat: Time.current.to_i, exp: iat + 300)
    claims = Base64.urlsafe_encode64({ kid:, aud:, seq:, iat:, exp:, kind:, payload: }.to_json, padding: false)
    "#{claims}.#{Base64.urlsafe_encode64(key.sign(nil, claims), padding: false)}"
  end
end

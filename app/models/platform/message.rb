# A message from the hosting platform that runs this board: a new plan, where to send the board's
# webhooks, a new owner name, the owner's password, or a request for the board's state. Only the platform holds the private key, so the owner can't
# lift their own card limit; the board holds the public keys in MUDDA_PLATFORM_KEYS
# ("kid:base64,kid:base64", the current key and the next during a rotation), the one setting a
# hosted board needs from its environment; everything else arrives in messages and is kept in the
# database. With no keys set, as when self-hosting, the board accepts no messages.
#
# A message is "<base64url claims>.<base64url Ed25519 signature of the first part>". The claims:
#
#   { "kid", "aud" (this board's host), "seq", "iat", "exp", "kind", "payload" }
#
# A message is refused unless it is signed by a known key, addressed to this board, fresh, and
# numbered above the last one applied, which stops a replay and an old plan arriving late.
# The owner's email is set once, at signup, so a payload that names one is refused.
class Platform::Message
  class Invalid < StandardError; end
  # The board's own configuration is at fault, not the message, so the platform should retry
  # once it is fixed rather than treat the message as refused.
  class Misconfigured < StandardError; end

  MAX_BYTES = 8.kilobytes
  MAX_LIFETIME = 5.minutes
  CLOCK_LEEWAY = 1.minute
  KINDS = %w[ plan.updated sync.configured name.updated password.set state.requested ]
  BCRYPT_DIGEST = %r{\A\$2[aby]\$\d{2}\$[./A-Za-z0-9]{53}\z}

  attr_reader :kind, :seq, :payload

  class << self
    def enabled?
      ENV["MUDDA_PLATFORM_KEYS"].present?
    end

    # The board's own host, from BASE_URL, so a request's Host header can't choose which board a
    # message counts as addressed to. Without BASE_URL (local development) it is the request's.
    def audience(request_host = nil)
      ENV["BASE_URL"].presence&.then { URI.parse(it).host } || request_host
    end

    def verify(token, host:, now: Time.current)
      raise Invalid, "too large" if token.bytesize > MAX_BYTES

      encoded_claims, encoded_signature = token.strip.split(".", 2)
      claims = decode_json(encoded_claims)
      key = keys[claims["kid"]] or raise Invalid, "unknown key"

      raise Invalid, "bad signature" unless key.verify(nil, decode(encoded_signature), encoded_claims)
      raise Invalid, "wrong audience" unless claims["aud"] == host
      raise Invalid, "expired" unless fresh?(claims, now)

      new(claims)
    end

    def keys
      ENV["MUDDA_PLATFORM_KEYS"].to_s.split(",").to_h do |entry|
        kid, public_key = entry.strip.split(":", 2)
        [ kid, OpenSSL::PKey.new_raw_public_key("ED25519", Base64.strict_decode64(public_key.to_s)) ]
      end
    rescue ArgumentError, OpenSSL::PKey::PKeyError
      raise Misconfigured, "MUDDA_PLATFORM_KEYS is malformed"
    end

    private
      def decode_json(encoded)
        JSON.parse(decode(encoded)).tap do |claims|
          raise Invalid, "malformed" unless claims.is_a?(Hash)
        end
      rescue JSON::ParserError
        raise Invalid, "malformed"
      end

      def decode(encoded)
        Base64.urlsafe_decode64(encoded.to_s)
      rescue ArgumentError
        raise Invalid, "malformed"
      end

      def fresh?(claims, now)
        issued_at, expires_at = claims.values_at("iat", "exp")

        issued_at.is_a?(Integer) && expires_at.is_a?(Integer) &&
          issued_at <= (now + CLOCK_LEEWAY).to_i &&
          expires_at <= issued_at + MAX_LIFETIME.to_i &&
          expires_at > now.to_i
      end
  end

  def initialize(claims)
    @kind, @seq, @payload = claims.values_at("kind", "seq", "payload")

    raise Invalid, "unknown kind" unless KINDS.include?(kind)
    raise Invalid, "bad sequence number" unless seq.is_a?(Integer) && seq.positive?
    raise Invalid, "bad payload" unless payload.is_a?(Hash)
    raise Invalid, "email can't be changed" if names_an_email?(payload)
  end

  # Applies the message to the account and returns what to answer: the board's state for a
  # state request, else nil. A message numbered at or below the last one applied changes nothing.
  def apply(account)
    case kind
    when "plan.updated"    then apply_plan(account)
    when "sync.configured" then apply_sync(account)
    when "name.updated"    then apply_name(account)
    when "password.set"    then apply_password(account)
    when "state.requested" then state_of(account)
    end
  end

  private
    def names_an_email?(value)
      case value
      when Hash  then value.any? { |key, nested| key.to_s.match?(/email/i) || names_an_email?(nested) }
      when Array then value.any? { names_an_email?(it) }
      else false
      end
    end

    # An unknown plan is refused rather than guessed at, so a platform ahead of this board's
    # release keeps retrying until the board knows it.
    def apply_plan(account)
      plan, upgrade_url = payload.values_at("plan", "upgrade_url")

      raise Invalid, "unknown plan" unless Account::CardLimited::PLANS.key?(plan)
      raise Invalid, "bad upgrade URL" unless upgrade_url.nil? || https_url?(upgrade_url)

      claim_seq(account, plan: plan, upgrade_url: upgrade_url)
      nil
    end

    def apply_sync(account)
      webhook_url, webhook_secret = payload.values_at("webhook_url", "webhook_secret")

      raise Invalid, "bad webhook URL" unless https_url?(webhook_url)
      raise Invalid, "bad webhook secret" unless webhook_secret.is_a?(String) && webhook_secret.length.between?(32, 255)

      claim_seq(account, webhook_url: webhook_url, webhook_secret: webhook_secret)
      nil
    end

    def apply_name(account)
      name, changed_at = payload["name"], name_changed_at

      account.transaction do
        account.users.order(:id).first!.sync_name(name, changed_at: changed_at) if claim_seq(account)
      end
      nil
    rescue ActiveRecord::RecordInvalid
      raise Invalid, "bad name"
    end

    def name_changed_at
      Time.iso8601(payload["name_changed_at"].to_s)
    rescue ArgumentError
      raise Invalid, "bad name_changed_at"
    end

    # The owner's password, chosen at signup or through the platform's forgot-password flow, as a
    # bcrypt hash, never the password itself. Taking it signs out every browser; tokens and
    # passkeys stay.
    def apply_password(account)
      digest = payload["password_digest"]

      raise Invalid, "bad password digest" unless digest.is_a?(String) && digest.match?(BCRYPT_DIGEST)

      account.transaction do
        if claim_seq(account)
          owner = account.users.order(:id).first!
          owner.update_column(:password_digest, digest)
          owner.sessions.browser.destroy_all
        end
      end
      nil
    end

    def state_of(account)
      owner = account.users.order(:id).first!

      account.reload
      { name: owner.name, name_changed_at: owner.name_changed_at&.iso8601(6), email: owner.email_address,
        plan: account[:plan], webhook_configured: account.webhook_url.present?, platform_seq: account.platform_seq }
    end

    # Takes the sequence number in the same statement that checks it, so two messages applied
    # at once can't both pass.
    def claim_seq(account, **changes)
      Account.where(id: account.id, platform_seq: ...seq).update_all(platform_seq: seq, **changes).positive?.tap do |claimed|
        StructuredLog.debug("platform.message.stale", kind: kind, seq: seq) unless claimed
      end
    end

    def https_url?(value)
      value.is_a?(String) && value.length <= 2048 && URI.parse(value).is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end
end

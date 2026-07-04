# The standing owner credential for this deployment.
#
# Mudda runs one identity per deployment. The owner signs in with their email and a deployment
# secret held in ENV["MUDDA_OWNER_PASSWORD"], verified here with a constant-time compare. This is
# the permanent sign-in method — it stays available whenever the secret is configured. Passkeys are
# an optional convenience layered on top (see My::PasskeysController) and never disable it. There is
# no password column: the secret lives only in the env.
module OwnerPassword
  class << self
    # Returns the owner Identity when password sign-in is available and +password+ matches the
    # deployment secret, otherwise nil. +email_address+ is normalized by the Identity finder.
    def authenticate(email_address, password)
      if enabled? && correct_password?(password)
        Identity.find_by(email_address: email_address)
      end
    end

    # Password sign-in is available whenever a secret is configured.
    def enabled?
      configured?
    end

    def configured?
      secret.present?
    end

    private
      def correct_password?(password)
        ActiveSupport::SecurityUtils.secure_compare(password.to_s, secret)
      end

      def secret
        ENV["MUDDA_OWNER_PASSWORD"].to_s
      end
  end
end

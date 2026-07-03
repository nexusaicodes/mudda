# Instance-wide bootstrap credential for day-0 sign-in.
#
# Mudda runs one identity per deployment. Before any passkey exists, the owner signs in with
# their email and a deployment secret held in ENV["MUDDA_OWNER_PASSWORD"], verified here with a
# constant-time compare. The moment a passkey is registered this path closes: +enabled?+ gates
# on there being no passkey anywhere, and both Sessions::PasswordsController and the
# PasswordLockdown middleware consult it. `bin/rails auth:reset` deletes passkeys to reopen it.
module BootstrapPassword
  class << self
    # Returns the owner Identity when password sign-in is available and +password+ matches the
    # deployment secret, otherwise nil. +email_address+ is normalized by the Identity finder.
    def authenticate(email_address, password)
      if enabled? && correct_password?(password)
        Identity.find_by(email_address: email_address)
      end
    end

    # Password sign-in is available only while a secret is configured and no passkey exists.
    def enabled?
      configured? && !ActionPack::Passkey.exists?
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

# The owner's password for this deployment.
#
# Mudda runs one user per deployment. A self-hosted board starts with ENV["MUDDA_OWNER_PASSWORD"];
# a hosted one is sent the owner's bcrypt hash by the platform (Platform::Message, password.set).
# Once the owner has a hash, from the platform or from changing it on their profile, it lives in
# users.password_digest and the env secret no longer signs anyone in. Either way
# the comparison is constant-time. Passkeys are an optional convenience layered on top (see
# My::PasskeysController) and never disable the password.
module OwnerPassword
  class << self
    # Returns the owner User when password sign-in is available and +password+ matches,
    # otherwise nil.
    def authenticate(email_address, password)
      if (user = User.find_by(email_address: email_address)) && correct_password?(user, password)
        user
      end
    end

    # Password sign-in is available whenever the owner has a stored password or a secret is
    # configured, and on a hosted board, whose password arrives from the platform after it boots.
    def enabled?
      User.where.not(password_digest: nil).exists? || configured? || Platform::Message.enabled?
    end

    def configured?
      secret.present?
    end

    private
      def correct_password?(user, password)
        if user.password_digest?
          user.authenticate_password(password.to_s).present?
        else
          configured? && ActiveSupport::SecurityUtils.secure_compare(password.to_s, secret)
        end
      end

      def secret
        ENV["MUDDA_OWNER_PASSWORD"].to_s
      end
  end
end

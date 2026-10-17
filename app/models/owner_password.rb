require "bcrypt"

# The owner's password for this deployment.
#
# Mudda runs one user per deployment. A self-hosted board starts with ENV["MUDDA_OWNER_PASSWORD"];
# a hosted one is sent the owner's bcrypt hash by the platform (Platform::Message, password.set).
# Once the owner has a hash, from the platform or from changing it on their profile, it lives in
# users.password_digest and the env secret no longer signs anyone in. Passkeys are an optional
# convenience layered on top (see My::PasskeysController) and never disable the password.
#
# Every attempt costs one bcrypt comparison, whether or not the email names the owner and
# whichever password is in force, so how long a sign-in takes gives away neither.
module OwnerPassword
  class << self
    # Returns the owner User when +password+ is theirs, otherwise nil.
    def authenticate(email_address, password)
      user = User.find_by(email_address: email_address)

      if correct_password?(user, password.to_s)
        user
      end
    end

    # Password sign-in is offered whenever the owner has a stored password or a secret is
    # configured, and on a hosted board (MUDDA_PLATFORM_KEYS set), whose password arrives from
    # the platform after it boots.
    def enabled?
      User.where.not(password_digest: nil).exists? || configured? || Platform::Message.enabled?
    end

    # Whether +user+ has a password to confirm: a stored one, or the env secret. Without either,
    # as for an owner who signs in with passkeys alone, or a hosted board the platform hasn't
    # sent a password yet, there is no current password to change.
    def set_for?(user)
      user.password_digest? || configured?
    end

    def configured?
      secret.present?
    end

    private
      def correct_password?(user, password)
        if user&.password_digest?
          user.authenticate_password(password).present?
        else
          stand_in_digest.is_password?(password)
          user.present? && configured? && ActiveSupport::SecurityUtils.secure_compare(password, secret)
        end
      end

      # Compared against when there is no stored hash to compare with, so that path costs what
      # checking a stored password does. It matches nothing anyone could send.
      def stand_in_digest
        @stand_in_digest ||= BCrypt::Password.create(SecureRandom.hex(32), cost: bcrypt_cost)
      end

      # The cost has_secure_password hashes with.
      def bcrypt_cost
        ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
      end

      def secret
        ENV["MUDDA_OWNER_PASSWORD"].to_s
      end
  end
end

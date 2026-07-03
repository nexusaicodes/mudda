# Forces the owner to register a passkey before using the app. After the day-0 password sign-in
# there are no passkeys yet, so every account-scoped request is redirected to the passkey list
# until one exists. Once a passkey is enrolled the gate opens and password sign-in closes for good
# (see BootstrapPassword). Enrollment surfaces opt out with +skip_passkey_enrollment+.
module PasskeyEnrollment
  extend ActiveSupport::Concern

  included do
    before_action :require_passkey_enrollment
  end

  class_methods do
    def skip_passkey_enrollment(**options)
      skip_before_action :require_passkey_enrollment, **options
    end
  end

  private
    def require_passkey_enrollment
      if enrollment_required?
        respond_to do |format|
          format.html { redirect_to my_passkeys_path }
          format.json { head :forbidden }
        end
      end
    end

    def enrollment_required?
      Current.account.present? && authenticated? && Current.identity.passkeys.none?
    end
end

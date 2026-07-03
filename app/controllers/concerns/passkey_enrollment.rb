# Forces the owner to register a passkey before using the app. After the day-0 password sign-in
# there are no passkeys yet, so every top-level page load is redirected to the passkey list until
# one exists. Once a passkey is enrolled the gate opens and password sign-in closes for good (see
# BootstrapPassword). Controllers opt out with +skip_passkey_enrollment+.
#
# Only full-page navigations are redirected. Background requests — Turbo Stream/Frame updates,
# prefetches, fetch/XHR, and non-HTML API calls — pass through untouched: redirecting them would
# discard their response or, for anything the layout auto-submits on load (such as the timezone
# sync), trap the page reloading against the gate.
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
      if enrollment_required? && page_navigation?
        redirect_to my_passkeys_path
      end
    end

    def enrollment_required?
      Current.account.present? && authenticated? && Current.identity.passkeys.none?
    end

    def page_navigation?
      request.get? && request.format.html? && !turbo_frame_request? && !prefetch_request?
    end

    def prefetch_request?
      request.headers["X-Sec-Purpose"].to_s.include?("prefetch")
    end
end

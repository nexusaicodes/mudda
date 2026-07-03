class My::TimezonesController < ApplicationController
  # The layout auto-submits this sync on every page load. It must bypass the passkey-enrollment
  # gate: otherwise the redirect to the enrollment page swallows the write, the browser/user
  # timezones never reconcile, and the page reloads in a loop before a passkey can be registered.
  skip_passkey_enrollment

  def update
    Current.user.settings.update!(timezone_name: timezone_param)
    head :no_content
  end

  private
    def timezone_param
      params[:timezone_name]
    end
end

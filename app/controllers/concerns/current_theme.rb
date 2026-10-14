# Renders each page in the owner's theme. "auto" leaves <html> without a data-theme, so the
# stylesheets follow the device's prefers-color-scheme; signed-out pages are always auto.
module CurrentTheme
  extend ActiveSupport::Concern

  included do
    helper_method :html_theme

    etag { html_theme }
  end

  private
    def html_theme
      theme = Current.user&.theme
      theme unless theme.nil? || theme == "auto"
    end
end

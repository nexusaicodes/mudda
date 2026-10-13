# Renders each request in the user's language: their setting, else the browser's
# Accept-Language, else English. JSON (and so every MCP tool call) always answers in English.
# A 401/403 is rendered by a before_action that runs ahead of this, so it stays in English.
module CurrentLocale
  extend ActiveSupport::Concern

  RTL_LOCALES = %i[ ar ]

  included do
    around_action :set_current_locale

    helper_method :html_direction

    etag { I18n.locale }
  end

  private
    def set_current_locale(&)
      I18n.with_locale(locale_for_request, &)
    end

    def locale_for_request
      if request.format.json?
        I18n.default_locale
      else
        Current.user&.locale.presence || locale_from_accept_language || I18n.default_locale
      end
    end

    def locale_from_accept_language
      accepted_languages.find { |language| I18n.available_locales.include?(language) }
    end

    def accepted_languages
      request.headers["Accept-Language"].to_s.split(",").filter_map do |entry|
        tag, *parameters = entry.split(";").map(&:strip)
        quality = parameters.find { it.start_with?("q=") }&.delete_prefix("q=")&.to_f || 1.0
        [ tag.split("-").first.downcase.to_sym, quality ] if tag.present? && quality.positive?
      end.sort_by { |_, quality| -quality }.map(&:first)
    end

    def html_direction
      RTL_LOCALES.include?(I18n.locale) ? "rtl" : "ltr"
    end
end

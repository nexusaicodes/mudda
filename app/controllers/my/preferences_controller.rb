# How the interface looks to its owner: the language (blank follows the browser's
# Accept-Language, see CurrentLocale) and the theme (auto follows the device's colour scheme).
# Only the keys sent are changed. A browser reads them on the profile.
class My::PreferencesController < ApplicationController
  wrap_parameters :preferences, include: %i[ locale theme ]

  serves_json :show, :update

  def show
    respond_to do |format|
      format.html { redirect_to user_path(Current.user) }
      format.json
    end
  end

  def update
    Current.user.settings.update!(preference_params)

    respond_to do |format|
      format.html { redirect_back_or_to user_path(Current.user) }
      format.json { head :no_content }
    end
  end

  private
    def preference_params
      params.fetch(:preferences, params).permit(:locale, :theme).to_h.tap do |preferences|
        preferences[:locale] = preferences[:locale].presence if preferences.key?(:locale)
      end
    end
end

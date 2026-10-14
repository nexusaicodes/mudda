# How the interface looks to its owner: the language (blank follows the browser's
# Accept-Language, see CurrentLocale) and the theme (auto follows the device's colour scheme).
# Only the keys sent are changed.
class My::PreferencesController < ApplicationController
  serves_json :show, :update

  def show
  end

  def update
    Current.user.settings.update!(preference_params)

    respond_to do |format|
      format.html { redirect_back_or_to user_path(Current.user) }
      format.json { head :no_content }
    end
  rescue ActiveRecord::RecordInvalid => error
    if request.format.json?
      render_json_errors(error.record.errors.to_hash.slice(:locale, :theme), status: :unprocessable_entity)
    else
      raise
    end
  end

  private
    def preference_params
      params.permit(:locale, :theme).to_h.tap do |preferences|
        preferences[:locale] = preferences[:locale].presence if preferences.key?(:locale)
      end
    end
end

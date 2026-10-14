# The zone dates are reckoned in when a request carries no browser zone of its own: a script or
# agent, or a browser before its timezone cookie is set (see CurrentTimezone). The key is the one
# GET /my/user reports. Every page a browser loads saves its own zone here when it differs, so a
# zone set over the API lasts until the owner next loads a page from a browser in another zone.
class My::TimezonesController < ApplicationController
  serves_json :update

  def update
    Current.user.settings.update!(timezone_name: params.require(:timezone))
    head :no_content
  rescue ActiveRecord::RecordInvalid => error
    if request.format.json?
      render_json_errors({ timezone: error.record.errors[:timezone_name] }, status: :unprocessable_entity)
    else
      raise
    end
  end
end

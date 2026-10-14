# The zone dates are reckoned in when a request carries no browser zone of its own: a script or
# agent, or a browser before its timezone cookie is set (see CurrentTimezone). The browser saves
# its zone here whenever it changes, so a value set over the API lasts until the owner next
# opens the app somewhere else.
class My::TimezonesController < ApplicationController
  wrap_parameters :timezone, include: %i[ timezone_name ]

  serves_json :update

  def update
    Current.user.settings.update!(timezone_params)
    head :no_content
  end

  private
    def timezone_params
      params.expect(timezone: [ :timezone_name ])
    end
end

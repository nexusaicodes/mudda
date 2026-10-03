class My::TimezonesController < ApplicationController
  serves_json :update

  def update
    Current.user.settings.update!(timezone_name: timezone_param)
    head :no_content
  end

  private
    def timezone_param
      params[:timezone_name]
    end
end

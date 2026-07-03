class Users::EventsController < ApplicationController
  include FilterScoped

  before_action :set_user

  def show
    @day_timeline = @user.timeline_for(day_param, filter: @filter)

    fresh_when @day_timeline
  end

  private
    def set_user
      @user = Current.user
    end

    def day_param
      if params[:day].present?
        Time.zone.parse(params[:day])
      else
        Time.current
      end
    end
end

class Users::EventsController < ApplicationController
  include FilterScoped

  before_action :set_user

  def show
    if day = day_param
      @day_timeline = @user.timeline_for(day, filter: @filter)
      fresh_when @day_timeline
    else
      head :not_found
    end
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
    rescue ArgumentError, TypeError
      nil
    end
end

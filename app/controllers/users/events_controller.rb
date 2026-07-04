class Users::EventsController < ApplicationController
  include DayTimelinesScoped

  before_action :set_user

  def show
    fresh_when @day_timeline
  end

  private
    def set_user
      @user = Current.user
    end
end

module DayTimelinesScoped
  extend ActiveSupport::Concern

  included do
    include FilterScoped

    before_action :set_day_timeline
  end

  private
    def set_day_timeline
      if timeline_day = day
        @day_timeline = Current.user.timeline_for(timeline_day, filter: @filter)
      else
        head :not_found
      end
    end

    def day
      if params[:day].present?
        Time.zone.parse(params[:day])
      else
        Time.current
      end
    rescue ArgumentError, TypeError
      nil
    end
end

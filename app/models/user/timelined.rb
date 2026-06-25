module User::Timelined
  def timeline_for(day, filter:)
    User::DayTimeline.new(self, day, filter)
  end
end

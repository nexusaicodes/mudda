module Card::Due
  extend ActiveSupport::Concern

  # Backlog holds unscheduled work, so a date is optional there; every other lane needs one.
  included do
    validates :due_on, presence: { message: "can't be blank outside Backlog" }, unless: :backlogged?
  end

  def overdue?
    due_on.present? && due_on.past?
  end
end

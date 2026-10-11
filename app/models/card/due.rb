module Card::Due
  extend ActiveSupport::Concern

  # Todo and Doing hold scheduled work, so a card there needs a date. Backlog holds unscheduled
  # work and Done holds finished work, so a date is optional in both.
  included do
    validates :due_on, presence: { message: :blank_while_active }, if: -> { active? && !due_on_supplied? }
    validate :due_on_is_a_date
  end

  def overdue?
    due_on.present? && due_on.past?
  end

  def days_until_due
    (due_on - Date.current).to_i if due_on
  end

  private
    # A string that doesn't parse ("2026-02-30", "next friday") casts to nil, and a non-string
    # (20261201, true) passes through the date cast unchanged; both are refused as invalid
    # rather than saved, and neither also reads as blank.
    def due_on_is_a_date
      if due_on_supplied? && !due_on.is_a?(Date)
        errors.add :due_on, :invalid
      end
    end

    def due_on_supplied?
      !(due_on.nil? && due_on_before_type_cast.blank?)
    end
end

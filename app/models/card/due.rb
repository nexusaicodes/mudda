module Card::Due
  extend ActiveSupport::Concern

  # Todo and Doing hold scheduled work, so a card there needs a date. Backlog holds unscheduled
  # work and Done holds finished work, so a date is optional in both.
  included do
    validates :due_on, presence: { message: :blank_while_active }, if: :active?
    validate :due_on_is_a_date
  end

  def overdue?
    due_on.present? && due_on.past?
  end

  def days_until_due
    (due_on - Date.current).to_i if due_on
  end

  private
    # A date that doesn't parse ("2026-02-30", "next friday") casts to nil; refuse it rather than
    # save the card undated.
    def due_on_is_a_date
      if due_on.nil? && due_on_before_type_cast.present?
        errors.add :due_on, :invalid
      end
    end
end

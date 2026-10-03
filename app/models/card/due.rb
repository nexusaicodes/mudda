module Card::Due
  extend ActiveSupport::Concern

  included do
    validates :due_on, presence: true
  end

  def overdue?
    due_on.present? && due_on.past?
  end
end

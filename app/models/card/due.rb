module Card::Due
  extend ActiveSupport::Concern

  included do
    validates :due_on, presence: true, if: :published?
  end

  def overdue?
    published? && due_on.present? && due_on.past?
  end
end

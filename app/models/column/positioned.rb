module Column::Positioned
  extend ActiveSupport::Concern

  included do
    scope :sorted, -> { order(position: :asc) }

    before_create :set_position
  end

  private
    def set_position
      max_position = board.columns.maximum(:position) || 0
      self.position = max_position + 1
    end
end

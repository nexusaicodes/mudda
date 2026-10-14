module Card::Pinnable
  extend ActiveSupport::Concern

  included do
    scope :pinned, -> { where(pinned: true) }
    scope :with_pinned_first, -> { prepend_order("cards.pinned DESC") }
  end

  def pin
    update! pinned: true
  end

  def unpin
    update! pinned: false
  end
end

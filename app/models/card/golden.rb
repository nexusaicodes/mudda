module Card::Golden
  extend ActiveSupport::Concern

  included do
    scope :golden, -> { where(golden: true) }
    scope :with_golden_first, -> { prepend_order("cards.golden DESC") }
  end

  def gild
    update! golden: true
  end

  def ungild
    update! golden: false
  end
end

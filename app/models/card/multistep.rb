module Card::Multistep
  extend ActiveSupport::Concern

  included do
    has_many :steps, dependent: :destroy

    # A card's steps are part of the card, so they are written with it rather than through a
    # collection of their own. The browser still posts them one at a time (see
    # Cards::StepsController), which is the same association by another door.
    accepts_nested_attributes_for :steps, allow_destroy: true
  end
end

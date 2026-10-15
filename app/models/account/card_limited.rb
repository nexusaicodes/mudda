# How many cards the account may ever create, by plan. Deleting a card doesn't hand its slot
# back, since cards_created_count only goes up.
#
# Only a board run by a hosting platform has a plan (see Platform::Message): the platform names
# it, and with it the upgrade URL that lifts the ceiling. Until the first plan arrives such a board
# is on the free plan. A board with no platform (self-hosted) has no plan and no ceiling.
module Account::CardLimited
  extend ActiveSupport::Concern

  # Each plan's ceiling; nil is none.
  PLANS = { "free" => 100, "premium" => nil }.freeze
  DEFAULT_PLAN = "free"
  NEAR_LIMIT = 10

  included do
    validates :plan, inclusion: { in: PLANS.keys }, allow_nil: true
  end

  def current_plan
    self[:plan] || DEFAULT_PLAN if Platform::Message.enabled?
  end

  def card_limit
    PLANS.fetch(current_plan) if current_plan
  end

  def card_limited?
    !card_limit.nil?
  end

  def cards_remaining
    [ card_limit - cards_created_count, 0 ].max if card_limited?
  end

  def card_limit_near?
    card_limited? && cards_remaining <= NEAR_LIMIT
  end

  def card_limit_reached?
    card_limited? && cards_remaining.zero?
  end

  def upgrade_url
    self[:upgrade_url] if Platform::Message.enabled?
  end

  # Counts one new card, in a single statement that only matches while the account is under its
  # ceiling, so two cards created together can't both take the last slot. Returns whether it did,
  # and leaves cards_created_count holding the stored count either way. The card that takes the
  # last slot tells the hosting platform, in the card's own transaction.
  def claim_card_slot
    accounts = Account.where(id: id)
    accounts = accounts.where(cards_created_count: ...card_limit) if card_limited?

    accounts.update_all("cards_created_count = cards_created_count + 1").positive?.tap do |claimed|
      self.cards_created_count = Account.where(id: id).pick(:cards_created_count)
      clear_attribute_changes %i[ cards_created_count ]

      WebhookDelivery.record "cards.limit_reached", card_limit: card_limit if claimed && card_limit_reached?
    end
  end
end

# An optional ceiling on how many cards the account may ever create. Deleting a card doesn't hand
# its slot back, since cards_created_count only goes up. The upgrade URL, when set, is where the
# app points the user to lift the ceiling.
#
# Once a hosting platform has pushed a plan (platform_seq above zero, see Platform::Message),
# the stored card_limit and upgrade_url rule, a nil limit meaning no ceiling. Until then they
# come from MUDDA_CARD_LIMIT (unset, blank, or not a whole number: no ceiling) and
# MUDDA_UPGRADE_URL.
module Account::CardLimited
  extend ActiveSupport::Concern

  NEAR_LIMIT = 10

  def card_limit
    if platform_managed?
      self[:card_limit]
    else
      Integer(ENV["MUDDA_CARD_LIMIT"].to_s, 10, exception: false)&.then { |limit| limit unless limit.negative? }
    end
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
    platform_managed? ? self[:upgrade_url] : ENV["MUDDA_UPGRADE_URL"].presence
  end

  def platform_managed?
    platform_seq.positive?
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

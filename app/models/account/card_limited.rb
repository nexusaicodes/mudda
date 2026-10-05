# An optional ceiling on how many cards the account may ever create, set by MUDDA_CARD_LIMIT
# (unset, blank, or not a whole number: no ceiling). Deleting a card doesn't hand its slot
# back, since cards_created_count only goes up. MUDDA_UPGRADE_URL, when set, is where the app
# points the user to lift the ceiling.
module Account::CardLimited
  extend ActiveSupport::Concern

  NEAR_LIMIT = 10

  def card_limit
    Integer(ENV["MUDDA_CARD_LIMIT"].to_s, 10, exception: false)&.then { |limit| limit unless limit.negative? }
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
    ENV["MUDDA_UPGRADE_URL"].presence
  end

  # Counts one new card, in a single statement that only matches while the account is under its
  # ceiling, so two cards created together can't both take the last slot. Returns whether it did,
  # and leaves cards_created_count holding the stored count either way.
  def claim_card_slot
    accounts = Account.where(id: id)
    accounts = accounts.where(cards_created_count: ...card_limit) if card_limited?

    accounts.update_all("cards_created_count = cards_created_count + 1").positive?.tap do
      self.cards_created_count = Account.where(id: id).pick(:cards_created_count)
      clear_attribute_changes %i[ cards_created_count ]
    end
  end
end

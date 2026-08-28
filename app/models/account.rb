class Account < ApplicationRecord
  include Searchable

  has_many :users, dependent: :destroy
  has_many :boards, dependent: :destroy

  validates :name, presence: true

  class << self
    def create_with_owner(account:, owner:)
      create!(**account).tap do |account|
        account.users.create!(**owner.with_defaults(verified_at: Time.current))
      end
    end
  end

  def account
    self
  end

  # Every card lives on one of the account's boards; there is no direct column to join on.
  def cards
    Card.where(board: boards)
  end
end

class Account < ApplicationRecord
  include CardLimited, Searchable

  has_many :users, dependent: :destroy
  has_many :boards, dependent: :destroy

  class << self
    def create_with_owner(owner:)
      create!.tap do |account|
        account.users.create!(**owner)
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

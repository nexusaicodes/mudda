class User < ApplicationRecord
  include Accessor, Avatar, Configurable, EmailAddressChangeable,
    Named, Searcher
  include Timelined # Depends on Accessor

  belongs_to :account
  belongs_to :identity, optional: true

  validates :name, presence: true

  scope :active, -> { where(active: true) }

  has_many :notes, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy

  has_many :filters, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy
  has_many :pins, dependent: :destroy
  has_many :pinned_cards, through: :pins, source: :card

  def deactivate
    transaction do
      update! active: false, identity: nil
      close_remote_connections
    end
  end

  def setup?
    name != identity.email_address
  end

  def verified?
    verified_at.present?
  end

  def verify
    update!(verified_at: Time.current) unless verified?
  end

  private
    def close_remote_connections
      ActionCable.server.remote_connections.where(current_user: self).disconnect(reconnect: false)
    end
end

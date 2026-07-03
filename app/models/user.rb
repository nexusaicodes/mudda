class User < ApplicationRecord
  include Accessor, Avatar, Configurable, Named, Searcher
  include Timelined # Depends on Accessor

  belongs_to :account
  belongs_to :identity, optional: true

  validates :name, presence: true

  scope :active, -> { where(active: true) }

  has_many :notes, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy

  has_many :filters, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy

  def deactivate
    update! active: false, identity: nil
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
end

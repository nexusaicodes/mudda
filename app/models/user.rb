class User < ApplicationRecord
  include Accessor, Avatar, Configurable, Named, Searcher

  has_passkeys name: :email_address, display_name: -> { name }

  belongs_to :account

  has_many :sessions, dependent: :destroy
  has_many :notes, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy
  has_many :filters, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy

  validates :name, presence: true
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  normalizes :email_address, with: ->(value) { value.strip.downcase.presence }

  scope :active, -> { where(active: true) }

  # The single owner of this deployment, as db/seeds.rb provisions them. MUDDA_OWNER_EMAIL
  # names them; without it, a user is the owner only when they are the only one there is.
  def self.owner
    if email_address = ENV["MUDDA_OWNER_EMAIL"].presence
      find_by(email_address:)
    else
      first if count == 1
    end
  end

  # Sessions survive: Authorization is what refuses a deactivated user, and it needs a live
  # credential to answer a JSON client 403 rather than 401.
  def deactivate
    update! active: false
  end

  def setup?
    name != email_address
  end

  def verified?
    verified_at.present?
  end

  def verify
    update!(verified_at: Time.current) unless verified?
  end
end

class User < ApplicationRecord
  include Accessor, Avatar, Configurable, Named, Searcher, Syncable

  has_passkeys name: :email_address, display_name: -> { name }
  has_secure_password validations: false

  # Set only once the owner changes their password; until then MUDDA_OWNER_PASSWORD is it (see OwnerPassword).
  # A blank password is ignored by has_secure_password, so changing it requires one.
  validates :password, length: { minimum: 8 }, confirmation: true, allow_nil: true
  validates :password, presence: true, on: :password_change

  belongs_to :account

  has_many :sessions, dependent: :destroy
  has_many :notes, foreign_key: :creator_id, inverse_of: :creator, dependent: :destroy

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

  # Takes a new password and its confirmation, refusing a blank one rather than keeping the old
  # password and reporting it changed.
  def change_password(attributes)
    assign_attributes(attributes)
    save(context: :password_change)
  end
end

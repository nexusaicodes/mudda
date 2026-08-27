class Identity < ApplicationRecord
  has_passkeys name: :email_address, display_name: -> { Current.user&.name || email_address }

  has_many :sessions, dependent: :destroy
  has_many :users, dependent: :nullify
  has_many :accounts, through: :users

  has_one_attached :avatar, dependent: :purge_later

  before_destroy :deactivate_users, prepend: true

  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  normalizes :email_address, with: ->(value) { value.strip.downcase.presence }

  # The single owner of this deployment, as db/seeds.rb provisions them. MUDDA_OWNER_EMAIL
  # names them; without it, an identity is the owner only when it is the only one there is.
  def self.owner
    if email_address = ENV["MUDDA_OWNER_EMAIL"].presence
      find_by(email_address:)
    else
      first if count == 1
    end
  end

  private
    def deactivate_users
      users.find_each(&:deactivate)
    end
end

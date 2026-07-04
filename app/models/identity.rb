class Identity < ApplicationRecord
  has_passkeys name: :email_address, display_name: -> { Current.user&.name || email_address }

  has_many :sessions, dependent: :destroy
  has_many :users, dependent: :nullify
  has_many :accounts, through: :users

  has_one_attached :avatar, dependent: :purge_later

  before_destroy :deactivate_users, prepend: true

  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }
  normalizes :email_address, with: ->(value) { value.strip.downcase.presence }

  def users_with_accounts
    users.joins(:account).includes(:account)
  end

  private
    def deactivate_users
      users.find_each(&:deactivate)
    end
end

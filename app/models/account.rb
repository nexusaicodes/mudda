class Account < ApplicationRecord
  include Account::Storage, Cancellable, Incineratable, MultiTenantable, Searchable

  has_one :join_code, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :boards, dependent: :destroy
  has_many :cards, dependent: :destroy
  has_many :columns, dependent: :destroy

  scope :active, -> { where.missing(:cancellation) }

  before_create :assign_external_account_id
  after_create :create_join_code

  validates :name, presence: true

  class << self
    def create_with_owner(account:, owner:)
      create!(**account).tap do |account|
        account.users.create!(role: :system, name: "System")
        account.users.create!(**owner.with_defaults(role: :owner, verified_at: Time.current))
      end
    end
  end

  def slug
    "/#{AccountSlug.encode(external_account_id)}"
  end

  def account
    self
  end

  def system_user
    users.find_by!(role: :system)
  end

  def active?
    !cancelled?
  end

  private
    def assign_external_account_id
      self.external_account_id ||= ExternalIdSequence.next
    end
end

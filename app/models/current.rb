# Mudda runs a single account, so there is no tenant in the URL to resolve. The account
# follows from whoever is signed in: session -> identity -> user -> account. An identity
# owns exactly one user (db/seeds.rb and Account.create_with_owner each provision one, and
# there is no way to join another), so the first user is the user.
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :identity, :account
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer

  def session=(value)
    super(value)

    self.identity = value&.identity
  end

  def identity=(identity)
    super(identity)

    self.user = identity&.users&.active&.first
    self.account = user&.account
  end

  # Jobs carry their tenant explicitly; see AccountTenanted.
  def with_account(value, &)
    with(account: value, &)
  end

  def without_account(&)
    with(account: nil, &)
  end
end

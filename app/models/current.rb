# Mudda runs a single account, so there is no tenant in the URL to resolve. The account
# follows from whoever is signed in: session -> user -> account.
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :account
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer

  def session=(value)
    super(value)

    self.user = value&.user
    # A deactivated user is still identified — Authorization is what refuses them — but they
    # have no account to act in.
    self.account =
      if user&.active?
        user.account
      end
  end

  # Jobs carry their tenant explicitly; see AccountTenanted.
  def with_account(value, &)
    with(account: value, &)
  end

  def without_account(&)
    with(account: nil, &)
  end
end

# Lazily add user and account context to error reports.
# Only evaluated when an error is actually reported.
Rails.error.add_middleware ->(error, context:, **) do
  context.merge \
    user_id: Current.user&.id,
    account_id: Current.account&.id
end

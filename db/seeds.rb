unless Rails.env.development?
  puts "WARN: Seeding is just for development!"
else
  # One account, one owner, no boards. Log in as david@example.com (the magic
  # link shows up in `make logs`) and create your first board after signing in.
  email_address = "david@example.com"
  account_name = "Mudda"
  external_account_id = ActiveRecord::FixtureSet.identify(account_name)

  identity = Identity.find_or_create_by!(email_address:, staff: true)

  account = Account.find_by(external_account_id:) ||
    Account.create_with_owner(
      account: { external_account_id:, name: account_name },
      owner: { name: "David", identity: }
    )

  puts %(Seeded account ##{account.external_account_id} "#{account.name}" — owner #{email_address})
end

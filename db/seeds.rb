# The single owner of this deployment. This file is the source of truth for who the account
# belongs to; the sign-in secret is MUDDA_OWNER_PASSWORD (see DOCKER.md). Idempotent — safe to
# rerun. Day 0: sign in with MUDDA_OWNER_EMAIL + MUDDA_OWNER_PASSWORD, then enroll a passkey.
email_address = ENV.fetch("MUDDA_OWNER_EMAIL") do
  Rails.env.local? ? "david@example.com" : abort("Set MUDDA_OWNER_EMAIL to provision the owner.")
end
owner_name = ENV.fetch("MUDDA_OWNER_NAME", email_address.split("@").first.capitalize)
account_name = ENV.fetch("MUDDA_OWNER_ACCOUNT", "Mudda")
external_account_id = ActiveRecord::FixtureSet.identify(account_name)

identity = Identity.find_or_create_by!(email_address:)

account = Account.find_by(external_account_id:) ||
  Account.create_with_owner(
    account: { external_account_id:, name: account_name },
    owner: { name: owner_name, identity: }
  )

puts %(Seeded account ##{account.external_account_id} "#{account.name}" — owner #{email_address})

# Without a password secret and with no passkey yet, there is no way to sign in. Fail fast in a
# real deployment; only tolerate it locally, where the secret is usually supplied at runtime.
if ENV["MUDDA_OWNER_PASSWORD"].blank? && !ActionPack::Passkey.exists?
  message = "MUDDA_OWNER_PASSWORD is not set and no passkey exists — there is no way to sign in."
  Rails.env.local? ? warn("WARNING: #{message} Day-0 sign-in is unavailable until you set it.") : abort(message)
end

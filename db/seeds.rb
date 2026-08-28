# The single owner of this deployment. This file is the source of truth for who the account
# belongs to; the standing sign-in secret is MUDDA_OWNER_PASSWORD (see DOCKER.md). Idempotent —
# safe to rerun. Sign in with MUDDA_OWNER_EMAIL + MUDDA_OWNER_PASSWORD; a passkey is optional.
email_address = ENV.fetch("MUDDA_OWNER_EMAIL") do
  Rails.env.local? ? "saksham@nexusai.world" : abort("Set MUDDA_OWNER_EMAIL to provision the owner.")
end
owner_name = ENV.fetch("MUDDA_OWNER_NAME", email_address.split("@").first.capitalize)
account_name = ENV.fetch("MUDDA_OWNER_ACCOUNT", "Mudda")

owner = User.find_by(email_address: email_address.strip.downcase) ||
  Account.create_with_owner(
    account: { name: account_name },
    owner: { name: owner_name, email_address: }
  ).users.first!

puts %(Seeded account ##{owner.account_id} "#{owner.account.name}" — owner #{owner.email_address})

# Without a password secret and with no passkey yet, there is no way to sign in. Fail fast in a
# real deployment; only tolerate it locally, where the secret is usually supplied at runtime.
if ENV["MUDDA_OWNER_PASSWORD"].blank? && !ActionPack::Passkey.exists?
  message = "MUDDA_OWNER_PASSWORD is not set and no passkey exists — there is no way to sign in."
  Rails.env.local? ? warn("WARNING: #{message} Sign-in is unavailable until you set it.") : abort(message)
end

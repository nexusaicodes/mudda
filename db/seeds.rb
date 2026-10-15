# The single owner of this deployment. This file is the source of truth for who the account
# belongs to; the standing sign-in secret is MUDDA_OWNER_PASSWORD (see DOCKER.md). Idempotent —
# safe to rerun. Sign in with MUDDA_OWNER_EMAIL + MUDDA_OWNER_PASSWORD; a passkey is optional.
email_address = ENV.fetch("MUDDA_OWNER_EMAIL") do
  Rails.env.local? ? "saksham@nexusai.world" : abort("Set MUDDA_OWNER_EMAIL to provision the owner.")
end
owner_name = ENV.fetch("MUDDA_OWNER_NAME", email_address.split("@").first.capitalize)

# The owner's email is set once and never changes, so an owner already here under another email
# means the environment is wrong; carrying on would create a second user.
if (existing = User.order(:id).first) && existing.email_address != email_address.strip.downcase
  abort "MUDDA_OWNER_EMAIL is #{email_address}, but this board's owner is #{existing.email_address}."
end

owner = User.find_by(email_address: email_address.strip.downcase) ||
  Account.create_with_owner(
    owner: { name: owner_name, email_address: }
  ).users.first!.tap do |user|
    # The language the owner signed up in on a hosting platform starts as their choice; from then on
    # it's theirs to change on the profile, so a later run leaves it alone.
    if (locale = ENV["MUDDA_OWNER_LOCALE"].presence) && !user.settings.update(locale:)
      warn "Ignoring MUDDA_OWNER_LOCALE=#{locale}: not one of #{I18n.available_locales.join(", ")}."
    end
  end

puts %(Seeded account ##{owner.account_id} — owner #{owner.email_address})

# Without a password secret, a stored password, a hosting platform to send one, or a passkey,
# there is no way to sign in. Fail fast in a real deployment; only tolerate it locally, where the
# secret is usually supplied at runtime.
unless OwnerPassword.enabled? || ActionPack::Passkey.exists?
  message = "MUDDA_OWNER_PASSWORD is not set, no platform is configured, and no passkey exists — there is no way to sign in."
  Rails.env.local? ? warn("WARNING: #{message} Sign-in is unavailable until you set it.") : abort(message)
end

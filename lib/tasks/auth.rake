namespace :auth do
  desc "Remove all passkeys and sign out every session (recovery for lost or broken passkeys)"
  task reset: :environment do
    passkeys = ActionPack::Passkey.delete_all
    sessions = Session.delete_all

    puts "Deleted #{passkeys} passkey(s) and #{sessions} session(s)."
    puts "Sign in with MUDDA_OWNER_EMAIL + MUDDA_OWNER_PASSWORD; enrolling a passkey again is optional."
  end
end

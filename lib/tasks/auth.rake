namespace :auth do
  desc "Reset auth to day 0: delete all passkeys and sessions so password sign-in is re-enabled"
  task reset: :environment do
    passkeys = ActionPack::Passkey.delete_all
    sessions = Session.delete_all

    puts "Deleted #{passkeys} passkey(s) and #{sessions} session(s)."
    puts "Password sign-in is re-enabled. Sign in with MUDDA_OWNER_EMAIL + MUDDA_OWNER_PASSWORD, then enroll a new passkey."
  end
end

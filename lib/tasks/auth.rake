namespace :auth do
  desc "Remove all passkeys and sign out every session (recovery for lost or broken passkeys)"
  task reset: :environment do
    passkeys = ActionPack::Passkey.delete_all
    sessions = Session.delete_all
    Doorkeeper::AccessToken.delete_all
    Doorkeeper::AccessGrant.delete_all

    puts "Deleted #{passkeys} passkey(s) and #{sessions} session(s)."
    puts "Sign in with MUDDA_OWNER_EMAIL + MUDDA_OWNER_PASSWORD; enrolling a passkey again is optional."
  end

  desc "Mint an API token for a script or agent (LABEL=claude SCOPES=\"read write delete\" bin/rails auth:token)"
  task token: :environment do
    user = User.owner or abort "No owner user — set MUDDA_OWNER_EMAIL to one, or run bin/rails db:seed first."

    session = user.sessions.create!(kind: :token, label: ENV["LABEL"].presence || "api", scopes: ENV["SCOPES"])

    warn "Token for #{user.email_address} labelled #{session.label.inspect} with scopes " \
      "#{session.scopes.join(" ").inspect}, valid for #{Session::API_TOKEN_EXPIRY.inspect}. " \
      "Minting replaced any token already carrying that label."
    warn %(  Authorization: Bearer <token>)
    puts session.token
  end

  desc "List the API tokens that have been minted"
  task tokens: :environment do
    sessions = Session.token.order(:created_at)

    if sessions.any?
      puts "LABEL\tSCOPES\tMINTED\tEXPIRES"
      sessions.each do |session|
        expires_at = session.created_at + Session::API_TOKEN_EXPIRY
        expiry = if session.oauth? then "connected over OAuth" elsif expires_at.past? then "expired" else expires_at.to_s end

        puts "#{session.label}\t#{session.scopes.join(" ")}\t#{session.created_at}\t#{expiry}"
      end
    else
      puts "No API tokens. Mint one with make token LABEL=claude."
    end
  end

  desc "Revoke the API tokens carrying a label (LABEL=claude bin/rails auth:revoke)"
  task revoke: :environment do
    label = ENV["LABEL"].presence or abort "Set LABEL to the token label you want revoked."

    count = Session.token.where(label: label).destroy_all.size # an OAuth client's tokens go with its session
    puts "Revoked #{count} token(s) labelled #{label.inspect}."
  end
end

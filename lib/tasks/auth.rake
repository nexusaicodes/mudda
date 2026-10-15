namespace :auth do
  desc "Remove all passkeys and any changed password, and end every session, API token, and OAuth grant (recovery for a lost password or passkey)"
  task reset: :environment do
    passkeys = ActionPack::Passkey.delete_all
    sessions = Session.delete_all
    Doorkeeper::AccessToken.delete_all
    Doorkeeper::AccessGrant.delete_all
    User.update_all(password_digest: nil)

    puts "Deleted #{passkeys} passkey(s) and #{sessions} session(s), and any changed password."
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

  desc "List the API tokens and connected OAuth clients"
  task tokens: :environment do
    sessions = Session.token.order(:created_at)

    if sessions.any?
      puts "LABEL\tSCOPES\tMINTED\tEXPIRES"
      sessions.each do |session|
        expiry = if session.expires_at.past? then "expired" elsif session.oauth? then "#{session.expires_at} unless used (OAuth)" else session.expires_at.to_s end

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

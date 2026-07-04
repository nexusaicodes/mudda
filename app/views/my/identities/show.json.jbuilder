json.id @identity.id

json.accounts @identity.users_with_accounts do |user|
  json.partial! "my/identities/account", account: user.account
  json.user user, partial: "users/user", as: :user
end

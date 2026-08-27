json.id @identity.id

json.account do
  json.partial! "my/identities/account", account: Current.account
  json.user Current.user, partial: "users/user", as: :user
end

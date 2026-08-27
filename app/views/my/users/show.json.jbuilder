json.partial! "users/user", user: @user

json.account do
  json.partial! "my/users/account", account: Current.account
end

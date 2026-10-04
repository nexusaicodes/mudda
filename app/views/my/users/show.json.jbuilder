json.partial! "users/user", user: @user

json.account do
  json.partial! "my/users/account", account: Current.account
end

# What the credential making this request may do, so a client can tell before it tries.
if Current.session.token?
  json.token do
    json.(Current.session, :label, :scopes)
  end
end

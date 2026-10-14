json.partial! "users/user", user: @user

# The zone this request's dates were reckoned in (see CurrentTimezone).
json.timezone Time.zone.name

json.account do
  json.partial! "my/users/account", account: Current.account
end

# What the credential making this request may do, so a client can tell before it tries.
if Current.session.token?
  json.token do
    json.(Current.session, :label, :scopes)
  end
end

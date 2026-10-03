json.cache! user do
  json.(user, :id, :name, :email_address, :active)
  json.created_at user.created_at.utc

  json.url user_url(user)
  json.avatar_url user_avatar_url(user)
end

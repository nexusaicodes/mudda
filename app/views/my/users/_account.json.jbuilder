json.cache! account do
  json.(account, :id, :name)
  json.created_at account.created_at.utc
end

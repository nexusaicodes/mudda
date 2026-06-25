json.board_id @board.id
json.all_access @board.all_access?

json.users @page.records do |user|
  json.partial! "users/user", user: user
  json.has_access accessed_user_ids.include?(user.id)
end

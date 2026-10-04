# A user holds one session per OAuth client (see Session::Oauth), held by the database so two
# consents arriving together can't both create one.
class IndexOneOauthSessionPerClient < ActiveRecord::Migration[8.2]
  def change
    add_index :sessions, %i[ user_id oauth_application_id ], unique: true, where: "oauth_application_id IS NOT NULL"
  end
end

# The owner's password once they change it on the profile or reset it through the hosting
# platform. Until then it is blank and MUDDA_OWNER_PASSWORD is the password.
class AddPasswordDigestToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :password_digest, :string
  end
end

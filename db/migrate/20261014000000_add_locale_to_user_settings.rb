# The user's interface language. Blank follows the browser's Accept-Language.
class AddLocaleToUserSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :user_settings, :locale, :string, limit: 255
  end
end

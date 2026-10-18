# The app has one look, light, so there is no theme to choose.
class RemoveThemeFromUserSettings < ActiveRecord::Migration[8.2]
  def change
    remove_column :user_settings, :theme, :string, limit: 255, default: "auto", null: false
  end
end

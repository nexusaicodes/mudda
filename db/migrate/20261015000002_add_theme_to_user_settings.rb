# The interface's colours: light, dark, or auto, which follows the device.
class AddThemeToUserSettings < ActiveRecord::Migration[8.2]
  def change
    add_column :user_settings, :theme, :string, limit: 255, null: false, default: "auto"
  end
end

class User::Settings < ApplicationRecord
  belongs_to :user

  normalizes :timezone_name, with: -> { it.to_s.strip.presence }

  THEMES = %w[ auto light dark ]

  validates :locale, inclusion: { in: -> { I18n.available_locales.map(&:to_s) } }, allow_nil: true
  validates :theme, inclusion: { in: THEMES }
  # Only a zone being saved is checked, so a name saved before zones were validated doesn't
  # block changing another setting; it reads as UTC until the browser replaces it.
  validate :timezone_name_names_a_zone, if: -> { timezone_name && will_save_change_to_timezone_name? }

  def timezone
    ActiveSupport::TimeZone[timezone_name.to_s] || default_timezone
  end

  private
    def timezone_name_names_a_zone
      errors.add :timezone_name, :invalid unless ActiveSupport::TimeZone[timezone_name]
    end

    def default_timezone
      ActiveSupport::TimeZone["UTC"]
    end
end

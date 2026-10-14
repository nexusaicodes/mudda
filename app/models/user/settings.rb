class User::Settings < ApplicationRecord
  belongs_to :user

  normalizes :timezone_name, with: ->(name) { User::Settings.canonical_timezone_name(name) }

  validates :locale, inclusion: { in: -> { I18n.available_locales.map(&:to_s) } }, allow_nil: true
  validate :timezone_name_names_a_zone, if: :timezone_name

  class << self
    # The zone a name stands for, under its canonical IANA name, so that the alias a browser may
    # report (Asia/Calcutta) and the zone it stands for (Asia/Kolkata) are one zone, as are a
    # Rails name (Eastern Time (US & Canada)) and its zone. Nil for a name that isn't a zone.
    def timezone_named(name)
      if zone = ActiveSupport::TimeZone[name.to_s]
        ActiveSupport::TimeZone[zone.tzinfo.canonical_identifier]
      end
    end

    # A name that isn't a zone is kept as sent, for the validation to refuse.
    def canonical_timezone_name(name)
      if name = name.to_s.strip.presence
        timezone_named(name)&.name || name
      end
    end
  end

  def timezone
    self.class.timezone_named(timezone_name) || default_timezone
  end

  private
    def timezone_name_names_a_zone
      errors.add :timezone_name, :invalid unless self.class.timezone_named(timezone_name)
    end

    def default_timezone
      ActiveSupport::TimeZone["UTC"]
    end
end

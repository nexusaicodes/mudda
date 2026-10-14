class User::Settings < ApplicationRecord
  belongs_to :user

  validates :locale, inclusion: { in: -> { I18n.available_locales.map(&:to_s) } }, allow_nil: true

  def timezone
    if timezone_name.present?
      ActiveSupport::TimeZone[timezone_name] || default_timezone
    else
      default_timezone
    end
  end

  private
    def default_timezone
      ActiveSupport::TimeZone["UTC"]
    end
end

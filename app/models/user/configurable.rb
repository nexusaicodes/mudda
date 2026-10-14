module User::Configurable
  extend ActiveSupport::Concern

  included do
    has_one :settings, class_name: "User::Settings", dependent: :destroy

    after_create :create_settings

    delegate :timezone, :locale, to: :settings
  end

  # Every user is created with settings, but one that somehow has none still reads the defaults
  # and saves its first preference rather than failing.
  def settings
    super || build_settings
  end
end

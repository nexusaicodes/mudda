require_relative "boot"

# Load every Rails framework except Action Cable — this app has no real-time
# broadcasting, so the cable framework (and its config) is intentionally absent.
require "rails"
%w[
  active_record/railtie
  active_storage/engine
  action_controller/railtie
  action_view/railtie
  action_mailer/railtie
  active_job/railtie
  action_mailbox/engine
  action_text/engine
  rails/test_unit/railtie
].each do |railtie|
  require railtie
end

require_relative "../lib/mudda"
require_relative "../lib/action_pack/railtie"

Bundler.require(*Rails.groups)

module Mudda
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Include the `lib` directory in autoload paths. Use the `ignore:` option
    # to list subdirectories that don't contain `.rb` files or that shouldn't
    # be reloaded or eager loaded.
    config.autoload_lib ignore: %w[ assets tasks rails_ext ]

    # Enable debug mode for Rails event logging so we get SQL query logs.
    # This was made necessary by the change in https://github.com/rails/rails/pull/55900
    config.after_initialize do
      Rails.event.debug_mode = true
    end

    # Use UUID primary keys for all new tables
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end

    config.action_pack.passkey.draw_routes = false
    config.action_pack.passkey.challenge_url = -> { my_passkey_challenge_path(script_name: "") }
  end
end

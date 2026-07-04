require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Base URL for links generated outside a request (jobs, etc.).
  # Set BASE_URL to your instance's public URL (e.g., https://mudda.example.com)
  if base_url = ENV["BASE_URL"].presence
    uri = URI.parse(base_url)
    url_options = { host: uri.host, protocol: uri.scheme }
    url_options[:port] = uri.port if uri.port != uri.default_port

    routes.default_url_options = url_options
  end

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{5.minutes.to_i}"
  }

  # Select Active Storage service via env var; default to local disk.
  # Don't overwrite if it's already been set (e.g. by mudda-saas)
  if config.active_storage.service.blank?
    config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "local").to_sym
  end

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Set DISABLE_SSL=true to disable all SSL options, rather than specify each individually
  ssl_enabled = "true" unless ENV["DISABLE_SSL"] == "true"

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
  config.assume_ssl = ENV.fetch("ASSUME_SSL", ssl_enabled) == "true"

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = ENV.fetch("FORCE_SSL", ssl_enabled) == "true"

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new(STDOUT)
                                       .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
                                       .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # In-memory cache store; no external cache backend.
  config.cache_store = :memory_store

  # Background jobs run in-process on the async adapter (no separate queue backend).
  config.active_job.queue_adapter = :async

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end

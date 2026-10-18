source "https://rubygems.org"

git_source(:bc) { |repo| "https://github.com/basecamp/#{repo}" }

gem "rails", github: "rails/rails", branch: "main"

# Assets & front end
gem "importmap-rails"
gem "propshaft"
gem "stimulus-rails"
gem "tailwindcss-rails", "~> 4.6"
gem "turbo-rails", github: "hotwired/turbo-rails", branch: "offline-cache"

# Drivers
gem "bootsnap", require: false
gem "puma", "~> 7.2", ">= 7.2.1"
gem "sqlite3", ">= 2.0"

# Features
gem "geared_pagination", "~> 1.2"
gem "rouge"
gem "jbuilder"
gem "lexxy", "0.9.14.beta"
gem "image_processing", "~> 1.14"
gem "platform_agent"
gem "useragent", bc: "useragent"
gem "mcp", "~> 1.6"
gem "bcrypt", "~> 3.1" # the owner password the board stores once it is changed or reset
gem "doorkeeper", "~> 5.9"
gem "rails-i18n"
gem "tzinfo-data" # the whole zone database, aliases a browser may report (Asia/Calcutta) included, whatever the OS ships

# Operations
gem "benchmark" # indirect dependency, being removed from Ruby 3.5 stdlib so here to quash warnings

group :development, :test do
  gem "i18n-tasks", require: false
  gem "debug"
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console", github: "rails/web-console"
end

group :test do
  gem "capybara"
  gem "json_schemer"
  gem "minitest-reporters", require: false
  gem "mocha"
  gem "selenium-webdriver"
end

# Tracing, inert unless OTEL_EXPORTER_OTLP_ENDPOINT or OTEL_TRACES_EXPORTER is set (config/initializers/opentelemetry.rb).
gem "opentelemetry-sdk", require: false
gem "opentelemetry-exporter-otlp", require: false
gem "opentelemetry-instrumentation-rails", require: false
gem "opentelemetry-instrumentation-net_http", require: false
gem "opentelemetry-helpers-sql-processor", require: false

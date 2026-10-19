class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include BlockSearchEngineIndexing
  include CurrentTimezone, CurrentLocale
  include JsonErrors, ServesJson
  include RequestForgeryProtection, TokenRateLimit
  include TurboFlash, ViewTransitions

  etag { "v1" }
  stale_when_importmap_changes
  allow_browser versions: :modern
end

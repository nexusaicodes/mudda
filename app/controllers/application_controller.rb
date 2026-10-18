class ApplicationController < ActionController::Base
  # First, so a refusal from Authentication or Authorization still carries the request's details.
  include CurrentRequest
  include Authentication
  include Authorization
  include BlockSearchEngineIndexing
  include CurrentTimezone, CurrentLocale, SetPlatform
  include JsonErrors, ServesJson
  include RequestForgeryProtection, TokenRateLimit
  include TurboFlash, ViewTransitions

  etag { "v1" }
  stale_when_importmap_changes
  allow_browser versions: :modern
end

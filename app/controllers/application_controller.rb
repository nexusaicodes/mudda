class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include BlockSearchEngineIndexing
  include CurrentRequest, CurrentTimezone, SetPlatform
  include JsonErrors, ServesJson
  include RequestForgeryProtection, TokenRateLimit
  include TurboFlash, ViewTransitions

  etag { "v1" }
  stale_when_importmap_changes
  allow_browser versions: :modern
end

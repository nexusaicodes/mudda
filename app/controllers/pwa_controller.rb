class PwaController < ApplicationController
  skip_forgery_protection

  # We need a stable URL at the root, so we can't use the regular asset path here.
  def service_worker
  end
end

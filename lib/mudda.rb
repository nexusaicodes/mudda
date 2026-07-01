module Mudda
  class << self
    # Retained as a no-op: bin/rails calls it before boot to optionally swap in
    # the SaaS Gemfile, which no longer exists here.
    def configure_bundle
    end
  end
end

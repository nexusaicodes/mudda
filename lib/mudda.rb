module Mudda
  class << self
    # Single-tenant OSS build on SQLite. The SaaS product layer and the MySQL
    # path have been removed, so this is always false; the predicate is kept
    # because it still guards a handful of view/job branches.
    def saas?
      false
    end

    # Retained as a no-op: bin/rails calls it before boot to optionally swap in
    # the SaaS Gemfile, which no longer exists here.
    def configure_bundle
    end
  end
end

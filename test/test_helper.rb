ENV["RAILS_ENV"] ||= "test"
ENV["MUDDA_OWNER_PASSWORD"] ||= "test-owner-password"
require_relative "../config/environment"

require "rails/test_help"
require "mocha/minitest"

unless [ "0", "false" ].include?(ENV["CI_PROGRESS_BAR"])
  require "minitest/reporters"
  Minitest::Reporters.use! Minitest::Reporters::ProgressReporter.new(detailed_skip: false)
end

module ActiveSupport
  class TestCase
    parallelize workers: :number_of_processors, work_stealing: ENV["WORK_STEALING"] != "false"

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include ActiveJob::TestHelper
    include ActionTextTestHelper, CachingTestHelper, CardTestHelper, ChangeTestHelper, SessionTestHelper

    # Jobs must carry their own account context via AccountTenanted,
    # not rely on Current.account leaking from the test setup.
    def perform_enqueued_jobs(...)
      saved_account = Current.account
      Current.account = nil
      super
    ensure
      Current.account = saved_account
    end

    setup do
      Current.account = accounts("37s")

      # The sign-in rate limit keeps its own store, which outlives a single test — so every
      # test starts from an unspent allowance.
      Sessions::PasswordsController::RATE_LIMIT_STORE.clear
    end

    teardown do
      Current.clear_all
    end
  end
end

class ActionDispatch::IntegrationTest
  private
    def without_action_dispatch_exception_handling
      original = Rails.application.config.action_dispatch.show_exceptions
      Rails.application.config.action_dispatch.show_exceptions = :none
      Rails.application.instance_variable_set(:@app_env_config, nil) # Clear memoized env_config
      yield
    ensure
      Rails.application.config.action_dispatch.show_exceptions = original
      Rails.application.instance_variable_set(:@app_env_config, nil) # Reset env_config
    end
end

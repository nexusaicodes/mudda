require "test_helper"

class ApplicationJobTest < ActiveJob::TestCase
  class ProbeJob < ApplicationJob
    def perform
      raise "should not run once the account is gone"
    end
  end

  test "discards a job whose account can no longer be located" do
    job_data = Current.with_account(accounts(:initech)) { ProbeJob.new.serialize }

    # Simulate the account having been deleted between enqueue and perform.
    GlobalID::Locator.stubs(:locate).raises(ActiveRecord::RecordNotFound)

    assert_nothing_raised do
      ActiveJob::Base.execute(job_data)
    end
  end
end

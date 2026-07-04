class ApplicationJob < ActiveJob::Base
  prepend AccountTenanted

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available.
  # AccountTenanted raises this when a job's account has since been deleted.
  discard_on ActiveJob::DeserializationError
end

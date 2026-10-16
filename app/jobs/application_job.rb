class ApplicationJob < ActiveJob::Base
  prepend AccountTenanted

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available.
  # AccountTenanted raises this when a job's account has since been deleted.
  discard_on ActiveJob::DeserializationError

  # A job given up on, by discard_on or by running out of retry_on attempts, is reported once
  # here; the error's own subscriber logs it with the job's context.
  after_discard do |job, error|
    next if error.is_a?(ActiveJob::DeserializationError)

    Rails.error.report(error, handled: false, source: "application.active_job",
      context: { job: job.class.name, job_id: job.job_id, executions: job.executions })
  end
end

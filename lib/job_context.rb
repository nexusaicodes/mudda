# Carries the enqueuing request's id into the job, and tags every event, log line and
# error report made while the job runs with its job_id and that request_id.
module JobContext
  extend ActiveSupport::Concern

  included do
    attr_accessor :request_id

    around_perform do |job, block|
      Rails.event.set_context(job_id: job.job_id, job: job.class.name, request_id: job.request_id)
      ActiveSupport::ExecutionContext[:request_id] = job.request_id
      block.call
    end
  end

  def initialize(...)
    super
    self.request_id = Rails.event.context[:request_id]
  end

  def serialize
    super.merge("request_id" => request_id)
  end

  def deserialize(job_data)
    super
    self.request_id = job_data["request_id"]
  end
end

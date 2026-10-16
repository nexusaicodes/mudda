# Retries a side effect that failed after its write committed (see AfterCommitSideEffects).
# A receiver that has since been deleted makes the repair moot, so the job is discarded quietly;
# one that keeps failing is reported by ApplicationJob once its attempts run out.
class AfterCommitRepairJob < ApplicationJob
  queue_as :backend

  retry_on StandardError, attempts: 8, wait: :polynomially_longer
  discard_on ActiveJob::DeserializationError

  def perform(receiver, side_effect, *arguments)
    receiver.public_send(side_effect, *arguments)
  end
end

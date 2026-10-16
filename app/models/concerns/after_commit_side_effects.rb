# A side effect of a write that has already committed — indexing it, recording its event,
# touching caches — can't undo the write, so its failure must not fail the request either.
# after_commit_side_effect reports the failure and hands the side effect to
# AfterCommitRepairJob, which retries it. Side effects are public methods and idempotent, so a
# repair that runs after a partial success does no harm.
module AfterCommitSideEffects
  # Calls side_effect on receiver (this record by default; a record or a class) with arguments,
  # which must be serializable by Active Job.
  def after_commit_side_effect(side_effect, *arguments, on: self)
    on.public_send(side_effect, *arguments)
  rescue StandardError => error
    Rails.error.report error, handled: true, severity: :error, source: "mudda.after_commit",
      context: { receiver: on.is_a?(Module) ? on.name : on, side_effect: side_effect.to_s }
    AfterCommitRepairJob.perform_later(on, side_effect.to_s, *arguments)
  end
end

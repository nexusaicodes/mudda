# frozen_string_literal: true

ActiveSupport.on_load(:active_job) do
  self.enqueue_after_transaction_commit = true
end

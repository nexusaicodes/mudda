class ApplicationRecord < ActiveRecord::Base
  include AfterCommitSideEffects

  primary_abstract_class

  # Raised by save! when a record other than the one being saved fails validation — one a
  # callback wrote. The client's input was this record, so the failure is a bug (a 500), not
  # the client's to fix (a 422). The RecordInvalid is its cause.
  class InvalidInCallback < StandardError; end

  def save!(...)
    super
  rescue ActiveRecord::RecordInvalid => error
    raise if error.record.equal?(self)

    raise InvalidInCallback, "#{error.record.class.name} written while saving #{self.class.name} is invalid: #{error.message}"
  end
end

# Multi-tenant safety: an attached blob must belong to the same account as the record
# it is attached to, so one account can never reference another's blob.
#
# Global/unaccounted attachments (Identity/User avatars) attach to records that have no
# account; `record.try(:account)` returns nil for them, so they are exempt.
ActiveSupport.on_load(:active_storage_attachment) do
  validate :blob_account_matches_record, on: :create

  private
    def blob_account_matches_record
      if record&.try(:account).present?
        unless blob&.account_id == record.account.id
          errors.add(:blob_id, "blob account must match record account")
        end
      end
    end
end

# Multi-tenant safety: an attached blob must belong to the same account as the record
# it is attached to, so one account can never reference another's blob.
#
# The check only runs when the record has an account. Identity avatars are exempt — Identity
# has no account, so `record.try(:account)` is nil. User avatars do run it (User belongs_to
# :account) and pass because the blob's account defaults to Current.account
# (see uuid_framework_models.rb), which matches the user's account.
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

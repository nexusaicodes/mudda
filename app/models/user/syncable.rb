# Keeps the owner's name in step with the hosting platform. Either side may rename; the newer
# change wins, and a tie keeps the name already here. A rename made here is queued for the
# platform in the same transaction (see WebhookDelivery); one that came from the platform isn't
# sent back.
module User::Syncable
  extend ActiveSupport::Concern

  included do
    before_save :stamp_name_change, if: :will_save_change_to_name?
    after_save :queue_name_change, if: -> { saved_change_to_name? && !Current.syncing }
  end

  def sync_name(name, changed_at:)
    if name_changed_at.nil? || changed_at > name_changed_at
      Current.set(syncing: true) { update!(name: name, name_changed_at: changed_at) }
    end
  end

  private
    def stamp_name_change
      self.name_changed_at = Time.current unless Current.syncing
    end

    def queue_name_change
      WebhookDelivery.record "user.updated", name: name, name_changed_at: name_changed_at.iso8601(6)
    end
end

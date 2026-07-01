ActiveSupport.on_load(:active_storage_attachment) do
  include Storage::AttachmentTracking
end

ActiveSupport.on_load(:active_storage_blob) do
  ActiveStorage::DiskController.after_action only: :show do
    expires_in 5.minutes, public: true
  end
end

ActiveSupport.on_load(:action_text_content) do
  # Install our extensions after ActionText::Engine's
  ActiveSupport.on_load(:active_storage_blob) do
    # Ensure all <action-text-attachment>s have a "url" attribute that's a relative
    # path (for portability across host name changes, beta environments, etc).
    def to_rich_text_attributes(*)
      super.merge url: Rails.application.routes.url_helpers.polymorphic_url(self, only_path: true)
    end
  end
end

# ActiveStorage::Record inherits from ActiveRecord::Base, not ApplicationRecord, so by default it
# gets its own connection pool. We want it to share ApplicationRecord's pool for transactional
# integrity, proper callback invocation, joins, etc. This delegates its connection pool to
# ApplicationRecord.
ActiveSupport.on_load(:active_storage_record) do
  class << self
    delegate :connection_pool, to: "ApplicationRecord"
  end
end

module ActiveStorageControllerExtensions
  extend ActiveSupport::Concern

  included do
    before_action do
      # Add script_name so that Disk Service will generate correct URLs for uploads
      ActiveStorage::Current.url_options = {
        protocol: request.protocol,
        host: request.host,
        port: request.port,
        script_name: request.script_name
      }
    end
  end
end

module ActiveStorageDirectUploadsControllerExtensions
  extend ActiveSupport::Concern

  included do
    include Authentication
    include Authorization
    include RequestForgeryProtection
  end
end

Rails.application.config.to_prepare do
  ActiveStorage::BaseController.include ActiveStorageControllerExtensions
  ActiveStorage::DirectUploadsController.include ActiveStorageDirectUploadsControllerExtensions
end

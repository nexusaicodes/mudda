ActiveSupport.on_load :active_storage_blob do
  def accessible_to?(user)
    attachments.includes(:record).any? { |attachment| attachment.accessible_to?(user) } || attachments.none?
  end

  def publicly_accessible?
    attachments.includes(:record).any? { |attachment| attachment.publicly_accessible? }
  end
end

ActiveSupport.on_load :active_storage_attachment do
  def accessible_to?(user)
    record.try(:accessible_to?, user)
  end

  def publicly_accessible?
    record.try(:publicly_accessible?)
  end
end

Rails.application.config.to_prepare do
  module ActiveStorage::Authorize
    extend ActiveSupport::Concern

    include Authentication

    included do
      # Ensure require_authentication runs after set_blob.
      skip_before_action :require_authentication
      before_action :require_authentication, :ensure_accessible, unless: :publicly_accessible_blob?

      # Representation controllers process the variant in set_representation, which stores
      # a new blob. Move that behind the checks above so no work is done for an
      # unauthorized request, and so the variant's blob is created with Current.account set
      # — the account comes from the signed-in identity, not the URL.
      if private_method_defined?(:set_representation)
        skip_before_action :set_representation
        before_action :set_representation
      end
    end

    private
      def publicly_accessible_blob?
        @blob.publicly_accessible?
      end

      def ensure_accessible
        unless @blob.accessible_to?(Current.user)
          head :forbidden
        end
      end

      def http_cache_forever(public: false, &block)
        super(public: public && publicly_accessible_blob?, &block)
      end
  end

  ActiveStorage::Blobs::RedirectController.include ActiveStorage::Authorize
  ActiveStorage::Blobs::ProxyController.include ActiveStorage::Authorize
  ActiveStorage::Representations::RedirectController.include ActiveStorage::Authorize
  ActiveStorage::Representations::ProxyController.include ActiveStorage::Authorize
end

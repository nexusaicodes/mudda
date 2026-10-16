# An image's variants are made when it is attached, after the record holding it has
# committed. A variant that fails to process is reported and queued for Active Storage's own
# CreateVariantsJob rather than failing the upload; until it exists, a request for it serves
# the original image.
module ActiveStorage::RepairableVariants
  private
    def process_immediate_variants_from_io(io)
      super
    rescue StandardError => error
      io.rewind if io.respond_to?(:rewind)
      self.immediate_variants_processed = true
      repair_immediate_variants(error)
    end

    def create_variants
      super
    rescue StandardError => error
      repair_immediate_variants(error)
    end

    def repair_immediate_variants(error)
      Rails.error.report error, handled: true, severity: :error, source: "mudda.after_commit",
        context: { receiver: blob, side_effect: "create_variants" }
      variants = named_variants.values.select { it.process(record) == :immediately }.map(&:transformations)
      ActiveStorage::CreateVariantsJob.perform_later(blob, variants: variants, process: :later) if variants.any?
    end
end

module ActiveStorage::OriginalOnVariantFailure
  private
    def set_representation
      super
    rescue StandardError => error
      raise if error.is_a?(ActiveRecord::RecordNotFound)

      Rails.error.report error, handled: true, severity: :error, source: "mudda.active_storage",
        context: { blob: @blob, variation_key: params[:variation_key] }
      redirect_to Rails.application.routes.url_helpers.rails_blob_path(@blob, disposition: params[:disposition], only_path: true)
    end
end

ActiveSupport.on_load(:active_storage_attachment) { prepend ActiveStorage::RepairableVariants }

Rails.application.config.to_prepare do
  ActiveStorage::Representations::BaseController.prepend ActiveStorage::OriginalOnVariantFailure
end

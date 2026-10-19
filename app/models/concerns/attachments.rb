module Attachments
  extend ActiveSupport::Concern

  # Variants used by ActionText embeds, processed immediately on attachment rather than lazily
  # on first view.
  #
  # Patched into ActionText::RichText in config/initializers/action_text.rb
  VARIANTS = {
    # vipsthumbnail used to create sized image variants has a intent setting to manage colors during
    # resize. By setting an invalid intent value the gif-incompatible intent filtering is skipped and
    # the gif can be rendered with all its frame intact.
    #
    # Only `n` is accepted as an override, using the full parameter name `intent` doesn’t work.
    large: { loader: { n: -1 }, resize_to_limit: [ 1024, 768 ] }
  }

  def attachments
    rich_text_record&.embeds || []
  end

  def has_attachments?
    attachments.any?
  end

  private
    def rich_text_record
      @rich_text_record ||= begin
        association = self.class.reflect_on_all_associations(:has_one).find { it.klass == ActionText::RichText }
        public_send(association.name)
      end
    end
end

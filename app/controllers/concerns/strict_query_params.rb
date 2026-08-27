# Refuses a query parameter we don't recognise, on JSON requests.
#
# Dropping an unrecognised key fails silently in whichever direction hurts: a misspelled
# `column_ids` widens a card index to every card, a misspelled `q` narrows a search to none.
# Either way the caller gets a plausible answer to a question it didn't ask.
#
# A browser sends assorted form and Turbo params and a person can't act on a 422, so only
# JSON — where the caller is a program — is held to this.
module StrictQueryParams
  extend ActiveSupport::Concern

  # The filter fields, plus the controls that page and shape a response.
  ALLOWED_QUERY_PARAMS = %w[
    indexed_by sorted_by creation card_ids column_ids board_ids terms
    page previous expand_all filter_id q target format
  ]

  included do
    before_action :reject_unknown_query_params
  end

  private
    def reject_unknown_query_params
      if request.format.json? && unknown_query_params.any?
        render_json_errors unknown_query_params.index_with { [ "is not a recognised parameter" ] },
          status: :unprocessable_entity
      end
    end

    # Rails reads `terms[]=a&terms[]=b` as `terms`, and route params never appear here — so
    # `id` and `board_id` are out of scope without having to be named.
    def unknown_query_params
      @unknown_query_params ||=
        request.query_parameters.keys.map { |key| key.delete_suffix("[]") }.uniq - ALLOWED_QUERY_PARAMS
    end
end

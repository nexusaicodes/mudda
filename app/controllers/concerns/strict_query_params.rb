# Refuses a query parameter we don't recognise, on JSON requests.
#
# Dropping an unrecognised key fails silently in whichever direction hurts: a misspelled
# `column_ids` widens a card index to every card, a misspelled `q` narrows a search to none.
# Either way the caller gets a plausible answer to a question it didn't ask.
#
# A browser sends assorted form and Turbo params and a person can't act on a 422, so only
# JSON — where the caller is a program — is held to this.
#
# Each host declares what it answers to by overriding +allowed_query_params+, so an endpoint
# is checked against its own contract rather than the union of everyone's.
module StrictQueryParams
  extend ActiveSupport::Concern

  # The controls that page and shape a response, which every index shares.
  PAGINATION_PARAMS = %w[ page previous expand_all ]

  included do
    include JsonErrors

    class_attribute :additional_query_params, default: []

    before_action :reject_unknown_query_params
  end

  class_methods do
    # Declared rather than overridden, so what an endpoint answers to doesn't depend on the
    # order its concerns happen to be included in.
    def allows_query_params(*names)
      self.additional_query_params = additional_query_params + names.map(&:to_s)
    end
  end

  private
    def reject_unknown_query_params
      if request.format.json? && unknown_query_params.any?
        render_json_errors unknown_query_params.index_with { [ "is not a recognised parameter" ] },
          status: :unprocessable_entity
      end
    end

    def allowed_query_params
      PAGINATION_PARAMS + self.class.additional_query_params
    end

    # Route params live in path_parameters, so `id` and `board_id` are out of scope without
    # having to be named — and Rack has already read `terms[]=a&terms[]=b` as `terms`.
    def unknown_query_params
      @unknown_query_params ||= request.query_parameters.keys - allowed_query_params
    end
end

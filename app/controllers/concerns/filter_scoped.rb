module FilterScoped
  extend ActiveSupport::Concern

  # The filter's own fields, read where they are defined rather than copied here.
  FILTER_QUERY_PARAMS = Filter::PERMITTED_PARAMS.flat_map { |param| param.is_a?(Hash) ? param.keys : param }

  included do
    include StrictQueryParams

    allows_query_params(*FILTER_QUERY_PARAMS)

    before_action :set_filter, only: :index
  end

  private
    # A value the filter doesn't know — `due=today`, a lane no board has — is refused rather
    # than dropped, since dropping it would answer for every card.
    def set_filter
      @filter = Filter.new(Current.user, params.permit(*Filter::PERMITTED_PARAMS))

      if @filter.invalid?
        if request.format.json?
          render_json_errors @filter.errors.to_hash, status: :unprocessable_entity
        else
          head :bad_request
        end
      end
    end
end

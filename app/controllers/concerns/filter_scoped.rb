module FilterScoped
  extend ActiveSupport::Concern

  # The filter's own fields, read where they are defined rather than copied here.
  FILTER_QUERY_PARAMS = Filter::PERMITTED_PARAMS.flat_map { |param| param.is_a?(Hash) ? param.keys : param } + [ :filter_id ]

  included do
    include StrictQueryParams

    allows_query_params(*FILTER_QUERY_PARAMS)

    before_action :set_filter
    before_action :set_user_filtering
  end

  private
    def set_filter
      if params[:filter_id].present?
        @filter = Current.user.filters.find(params[:filter_id])
      else
        @filter = Current.user.filters.from_params filter_params
      end
    end

    def filter_params
      params.with_defaults(**Filter.default_values).permit(*Filter::PERMITTED_PARAMS)
    end

    def set_user_filtering
      @user_filtering = User::Filtering.new(Current.user, @filter, expanded: expanded_param)
    end

    def expanded_param
      ActiveRecord::Type::Boolean.new.cast(params[:expand_all])
    end
end

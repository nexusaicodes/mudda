class SearchesController < ApplicationController
  include Turbo::DriveHelper, StrictQueryParams

  allows_query_params :q

  def show
    @query = params[:q].blank? ? nil : params[:q]

    if card = card_matching_number
      respond_to do |format|
        format.html { @card = card }
        format.json { set_page_and_extract_portion_from Current.user.accessible_cards.where(id: card.id) }
      end
    else
      respond_to do |format|
        format.html do
          set_page_and_extract_portion_from Current.user.search(@query)
          @recent_search_queries = Current.user.search_queries.order(updated_at: :desc).limit(10)
        end

        format.json do
          set_page_and_extract_portion_from \
            Current.user.accessible_cards.mentioning(@query, user: Current.user).distinct.latest.preloaded
        end
      end
    end
  end

  private
    # Jump straight to a card only when the query is exactly a card number; a looser
    # match would hijack any full-text query that merely starts with a digit.
    def card_matching_number
      Current.user.accessible_cards.find_by(number: @query) if @query&.match?(/\A\d+\z/)
    end
end

class SearchesController < ApplicationController
  include Turbo::DriveHelper, StrictQueryParams

  serves_json :show

  allows_query_params :q

  MATCH_LIMIT = 200

  # A person gets matches grouped by board, read from the full-text index; a program gets a
  # paginated card list.
  def show
    @query = params[:q].presence

    respond_to do |format|
      format.html { @groups = grouped_matches }
      format.json do
        set_page_and_extract_portion_from \
          Current.user.accessible_cards.mentioning(@query, user: Current.user).distinct.latest.preloaded
      end
    end
  end

  private
    # Each card once, however many of its notes matched, under its board. The board the search
    # was made from comes first, then the boards with the most matching cards.
    def grouped_matches
      matches = Current.user.search(@query).includes(card: :column).limit(MATCH_LIMIT).to_a
      by_board = matches.group_by(&:card).group_by { |card, _| card.board }

      by_board.sort_by { |board, cards| [ board.id == searched_from_board_id ? 0 : 1, -cards.size, board.name.downcase ] }
    end

    # The search box sits in the page footer and reads no page state, so the board is taken
    # from the page that made the request.
    def searched_from_board_id
      @searched_from_board_id ||= URI(request.referer.to_s).path.to_s[%r{\A/boards/(\d+)}, 1].to_i
    rescue URI::InvalidURIError
      @searched_from_board_id = 0
    end
end

class SearchesController < ApplicationController
  include Turbo::DriveHelper, StrictQueryParams

  serves_json :show

  allows_query_params :q

  RESULTS_PER_BOARD = 5

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
    # Each board with how many of its cards match and the latest few of them, each card once
    # however many of its notes matched. The board the search was made from comes first, then
    # the boards with the most matching cards.
    def grouped_matches
      counts = Current.user.search_counts_by_board(@query)
      matches = Current.user.search_boards(@query, limit: RESULTS_PER_BOARD)

      Current.user.boards.where(id: counts.keys)
        .sort_by { |board| [ board.id == searched_from_board_id ? 0 : 1, -counts[board.id], board.name.downcase ] }
        .map { |board| [ board, counts[board.id], matches.fetch(board.id, []) ] }
    end

    # The search box sits in the page footer and reads no page state, so the board is taken
    # from the page that made the request.
    def searched_from_board_id
      @searched_from_board_id ||= URI(request.referer.to_s).path.to_s[%r{\A/boards/(\d+)}, 1].to_i
    rescue URI::InvalidURIError
      @searched_from_board_id = 0
    end
end

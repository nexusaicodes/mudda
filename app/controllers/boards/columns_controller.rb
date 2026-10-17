class Boards::ColumnsController < ApplicationController
  include BoardScoped, StrictQueryParams

  before_action :set_column

  # A board's columns are fixed, so they travel with the board itself (see
  # boards/show.json.jbuilder) rather than as a collection of their own. What is left here is
  # the browser's: one lane's cards, loaded into the lane's frame on the board page. A lane has
  # no page of its own, so a plain visit goes to the board. With `due=soon` the lane holds only
  # its cards due by tomorrow, as the board's toggle asks.
  def show
    if turbo_frame_request?
      set_page_and_extract_portion_from lane_cards.by_due_date.with_pinned_first.preloaded
      fresh_when etag: [ @page.records, Date.current ]
    else
      redirect_to board_path(@board, anchor: helpers.dom_id(@column))
    end
  end

  private
    def lane_cards
      params[:due] == "soon" ? @column.cards.due_soon : @column.cards
    end

    def set_column
      @column = @board.columns.find(params[:id])
    end
end

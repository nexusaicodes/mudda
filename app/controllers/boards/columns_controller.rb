class Boards::ColumnsController < ApplicationController
  wrap_parameters :column, include: %i[ color ]

  include BoardScoped, StrictQueryParams

  before_action :set_column

  # A board's columns are fixed, so they travel with the board itself (see
  # boards/show.json.jbuilder) rather than as a collection of their own. What is left here is
  # the browser's: one lane's cards, loaded into the lane's frame on the board page, and the
  # color picker. A lane has no page of its own, so a plain visit goes to the board.
  def show
    if turbo_frame_request?
      set_page_and_extract_portion_from @column.cards.by_due_date.with_pinned_first.preloaded
      fresh_when etag: [ @page.records, Date.current ]
    else
      redirect_to board_path(@board, anchor: helpers.dom_id(@column))
    end
  end

  # Color is a display preference, so it is set from the board page and nowhere else.
  def update
    @column.update!(column_params)
  end

  private
    def set_column
      @column = @board.columns.find(params[:id])
    end

    def column_params
      params.expect(column: [ :color ])
    end
end

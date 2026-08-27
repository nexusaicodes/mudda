class Boards::ColumnsController < ApplicationController
  wrap_parameters :column, include: %i[ color ]

  include BoardScoped, BrowserOnly, StrictQueryParams

  before_action :set_column

  # A board's columns are fixed, so they travel with the board itself (see
  # boards/show.json.jbuilder) rather than as a collection of their own. What is left here is
  # the browser's: one lane's cards, and the color picker.
  def show
    set_page_and_extract_portion_from @column.cards.published.by_due_date.with_golden_first.preloaded
    fresh_when etag: [ @page.records, Date.current ]
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

class Boards::ColumnsController < ApplicationController
  wrap_parameters :column, include: %i[ color ]

  include BoardScoped

  before_action :set_column, only: %i[ show update ]

  def index
    @columns = @board.columns.sorted
    fresh_when etag: @columns
  end

  def show
    set_page_and_extract_portion_from @column.cards.published.latest.with_golden_first.preloaded
    fresh_when etag: @page.records
  end

  # Columns are fixed; only their color is editable.
  def update
    @column.update!(column_params)

    respond_to do |format|
      format.turbo_stream
      format.json { render :show }
    end
  end

  private
    def set_column
      @column = @board.columns.find(params[:id])
    end

    def column_params
      params.expect(column: [ :color ])
    end
end

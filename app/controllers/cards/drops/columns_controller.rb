class Cards::Drops::ColumnsController < ApplicationController
  include CardScoped, BrowserOnly

  def create
    @column = @board.columns.find(params[:column_id])
    @source_column = @card.column
    @card.triage_into(@column)
  end
end

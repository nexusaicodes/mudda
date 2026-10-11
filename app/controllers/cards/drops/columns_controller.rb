class Cards::Drops::ColumnsController < ApplicationController
  include CardScoped

  # Both lanes are repainted from the database either way, so a refused move — a card with
  # no due date dropped in Todo or Doing — snaps back to where it was, with the reason.
  def create
    @column = @board.columns.find(params[:column_id])
    @source_column = @card.column

    @card.update(column: @column)
  end
end

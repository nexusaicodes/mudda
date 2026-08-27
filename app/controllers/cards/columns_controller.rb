class Cards::ColumnsController < ApplicationController
  include CardScoped

  def edit
    @columns = @board.columns.sorted

    fresh_when etag: [ @card, @columns ]
  end

  def update
    @card.triage_into(column)

    respond_to do |format|
      format.html { redirect_back_or_to board_card_path(@board, @card) }
      format.json { render "cards/show" }
    end
  end

  private
    # Scoped to the card's own board, so a column id from anywhere else is a 404 rather than
    # a move across boards.
    def column
      @board.columns.find(params[:column_id])
    end
end

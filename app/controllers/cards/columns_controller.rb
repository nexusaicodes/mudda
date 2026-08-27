class Cards::ColumnsController < ApplicationController
  include CardScoped, BrowserOnly

  # The lane picker. A card's column is one of its attributes, so everywhere but the browser
  # moves it with a PUT to the card itself (see CardsController).
  def edit
    @columns = @board.columns.sorted

    fresh_when etag: [ @card, @columns ]
  end

  def update
    @card.triage_into(column)
    redirect_back_or_to board_card_path(@board, @card)
  end

  private
    # Scoped to the card's own board, so a column id from anywhere else is a 404 rather than
    # a move across boards.
    def column
      @board.columns.find(params[:column_id])
    end
end

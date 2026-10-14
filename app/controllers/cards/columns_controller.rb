class Cards::ColumnsController < ApplicationController
  include CardScoped

  # The lane picker. A card's column is one of its attributes, so everywhere but the browser
  # moves it with a PUT to the card itself (see CardsController).
  def edit
    @columns = @board.columns.sorted

    fresh_when etag: [ @card, @columns ]
  end

  def update
    if @card.update(column: column)
      redirect_back_or_to board_card_path(@board, @card)
    else
      redirect_back_or_to board_card_path(@board, @card), alert: @card.errors.full_messages.to_sentence
    end
  end

  private
    # Scoped to the card's own board, so a column id from anywhere else is a 404 rather than
    # a move across boards.
    def column
      @board.columns.find(params[:column_id])
    end
end

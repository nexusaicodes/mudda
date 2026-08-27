class Cards::ColumnsController < ApplicationController
  before_action :set_card

  def edit
    @columns = @card.board.columns.sorted

    fresh_when etag: [ @card, @columns ]
  end

  def update
    @card.triage_into(column)

    respond_to do |format|
      format.html { redirect_back_or_to card_path(@card) }
      format.json { render "cards/show" }
    end
  end

  private
    def set_card
      @card = Current.user.accessible_cards.find_by!(number: params[:card_id])
    end

    # Scoped to the card's own board, so a column id from anywhere else is a 404 rather than
    # a move across boards.
    def column
      @card.board.columns.find(params[:column_id])
    end
end

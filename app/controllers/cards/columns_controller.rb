class Cards::ColumnsController < ApplicationController
  before_action :set_card

  def edit
    @columns = @card.board.columns.sorted

    fresh_when etag: [ @card, @columns ]
  end

  def update
    if column = @card.board.columns.find_by(id: params[:column_id])
      @card.triage_into(column)
    end

    redirect_back_or_to card_path(@card)
  end

  private
    def set_card
      @card = Current.user.accessible_cards.find_by!(number: params[:card_id])
    end
end

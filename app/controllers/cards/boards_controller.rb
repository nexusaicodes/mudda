class Cards::BoardsController < ApplicationController
  include CardScoped

  def edit
    @boards = Current.user.boards.ordered_by_recent_activity
    fresh_when @boards
  end

  # The route already spends :board_id on the card's own board, so the destination carries
  # its own name.
  def update
    @card.move_to Current.user.boards.find(params[:destination_id])

    respond_to do |format|
      format.html { redirect_to @card }
      format.json { render "cards/show" }
    end
  end
end

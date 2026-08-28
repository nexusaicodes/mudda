module CardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_board, :set_card
  end

  private
    def set_board
      @board = Current.user.boards.find(params[:board_id])
    end

    def set_card
      @card = @board.cards.find_by!(number: params[:card_id])
    end

    def render_card_replacement
      render turbo_stream: turbo_stream.replace([ @card, :card_container ], partial: "cards/container", method: :morph, locals: { card: @card.reload })
    end
end

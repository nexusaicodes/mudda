class CardsController < ApplicationController
  wrap_parameters :card, include: %i[ title description image due_on created_at last_active_at board_id column_id golden steps_attributes ]

  include FilterScoped

  before_action :set_board, if: -> { params[:board_id].present? }
  before_action :set_card, only: %i[ show edit update destroy ]
  before_action :redirect_if_drafted, only: :show

  # Nested under a board, the index answers for that board alone; at the top level it spans
  # every board. The filter narrows either one.
  def index
    set_page_and_extract_portion_from within_board(@filter.cards)
  end

  def create
    respond_to do |format|
      format.html do
        card = Current.user.draft_new_card_in(@board)
        redirect_to board_card_draft_path(card.board, card)
      end

      format.json do
        # The board comes from the path, and a new card always starts in that board's Triage
        # column, so neither id is read from the body.
        @card = @board.cards.new card_params.except(:board_id, :column_id).merge(creator: Current.user, status: "published")

        if @card.save
          render :show, status: :created, location: board_card_path(@board, @card, format: :json)
        else
          render json: { errors: @card.errors }, status: :unprocessable_entity
        end
      end
    end
  end

  def show
  end

  def edit
  end

  def update
    respond_to do |format|
      format.html do
        @card.update! card_attributes
        redirect_to @card
      end
      format.turbo_stream { @card.update! card_attributes }
      format.json do
        if @card.update card_attributes
          render :show
        else
          render json: { errors: @card.errors }, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    @card.destroy!

    respond_to do |format|
      format.html { redirect_to @card.board, notice: "Card deleted" }
      format.json { head :no_content }
    end
  end

  private
    # Narrows the query, not the filter: Filter#boards is a HABTM, so assigning board_ids on
    # a saved filter would rewrite its boards on disk as a side effect of a GET.
    def within_board(cards)
      @board ? cards.where(board: @board) : cards
    end

    def set_board
      @board = Current.user.boards.find params[:board_id]
    end

    def set_card
      @card = @board.cards.find_by!(number: params[:id])
    end

    def redirect_if_drafted
      redirect_to board_card_draft_path(@card.board, @card) if @card.drafted?
    end

    def card_params
      params.expect(card: [ :title, :description, :image, :due_on, :created_at, :last_active_at, :golden,
        :board_id, :column_id, steps_attributes: [ [ :id, :content, :completed, :_destroy ] ] ])
    end

    # A card's board and column are two of its attributes, so moving it either way is an
    # update. Both associations are resolved rather than assigned by id, so neither can name
    # a record the caller can't reach; a blank one leaves the card where it is. Note that a
    # board change lands the card in the destination's Triage column (Card#handle_board_change),
    # so a column_id sent alongside a board_id does not survive the move.
    def card_attributes
      card_params.except(:board_id, :column_id).merge(destination_board).merge(destination_column)
    end

    def destination_board
      if board_id = card_params[:board_id].presence
        { board: Current.user.boards.find(board_id) }
      else
        {}
      end
    end

    # Scoped to the card's own board, so a column id from anywhere else is a 404 rather than
    # a move across boards.
    def destination_column
      if column_id = card_params[:column_id].presence
        { column: @card.board.columns.find(column_id) }
      else
        {}
      end
    end
end

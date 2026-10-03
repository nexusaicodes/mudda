class CardsController < ApplicationController
  wrap_parameters :card, include: %i[ title description due_on created_at last_active_at board_id column_id golden steps_attributes ]

  include FilterScoped

  before_action :set_board, if: -> { params[:board_id].present? }
  before_action :set_card, only: %i[ show edit update destroy ]

  # Nested under a board, the index answers for that board alone; at the top level it spans
  # every board. The filter narrows either one.
  def index
    set_page_and_extract_portion_from within_board(@filter.cards)
  end

  def new
    @card = @board.cards.new
  end

  # The board comes from the path, and a new card always starts in that board's Triage column,
  # so neither id is read from the body.
  def create
    @card = @board.cards.new card_params.except(:board_id, :column_id).merge(creator: Current.user)

    respond_to do |format|
      # The form has to come back with its errors on it, so this is the one write that reads
      # a return value rather than leaving the envelope to JsonErrors.
      format.html do
        if @card.save
          redirect_to @card
        else
          render :new, status: :unprocessable_entity
        end
      end

      format.json do
        @card.save!
        render :show, status: :created, location: board_card_path(@board, @card, format: :json)
      end
    end
  end

  def show
  end

  def edit
  end

  # A move gives the card a new address — its board and its number both change — so the
  # response hands the client the new one: the browser is sent there, since a page left at the
  # old URL would post its forms to a card that no longer answers to it, and JSON names it in
  # Location.
  def update
    respond_to do |format|
      format.html do
        @card.update! card_attributes
        redirect_to @card, status: :see_other
      end
      format.turbo_stream do
        @card.update! card_attributes
        redirect_to @card, status: :see_other if moved?
      end
      format.json do
        @card.update! card_attributes
        render :show, location: (board_card_url(@card.board, @card) if moved?)
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

    def moved?
      @card.board != @board
    end

    def card_params
      params.expect(card: [ :title, :description, :due_on, :created_at, :last_active_at, :golden,
        :board_id, :column_id, steps_attributes: [ [ :id, :content, :completed, :_destroy ] ] ])
    end

    # A card's board and column are two of its attributes, so moving it either way is an
    # update, and the request names where the card ends up. Both associations are resolved
    # rather than assigned by id, so neither can name a record the caller can't reach; a blank
    # one leaves the card where it is. A column_id names a lane on the board the card ends on —
    # the destination when board_id is sent too, which with no column_id lands the card in that
    # board's Triage (Card#land_in_destination_triage).
    def card_attributes
      card_params.except(:board_id, :column_id).merge(destination_board).merge(destination_column)
    end

    def destination_board
      @destination_board ||= if board_id = card_params[:board_id].presence
        { board: Current.user.boards.find(board_id) }
      else
        {}
      end
    end

    # Scoped to the board the card ends on, so a column id from anywhere else is a 404 rather
    # than a card on one board in another board's lane.
    def destination_column
      if column_id = card_params[:column_id].presence
        { column: destination_board.fetch(:board, @card.board).columns.find(column_id) }
      else
        {}
      end
    end
end

class CardsController < ApplicationController
  wrap_parameters :card, include: %i[ title description image due_on created_at last_active_at ]

  include FilterScoped

  before_action :set_board, only: %i[ create ]
  before_action :set_card, only: %i[ show edit update destroy ]
  before_action :redirect_if_drafted, only: :show

  def index
    set_page_and_extract_portion_from @filter.cards
  end

  def create
    respond_to do |format|
      format.html do
        card = Current.user.draft_new_card_in(@board)
        redirect_to card_draft_path(card)
      end

      format.json do
        @card = @board.cards.new card_params.merge(creator: Current.user, status: "published")

        if @card.save
          render :show, status: :created, location: card_path(@card, format: :json)
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
      format.turbo_stream { @card.update! card_params }
      format.json do
        if @card.update card_params
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
    def set_board
      @board = Current.user.boards.find params[:board_id]
    end

    def set_card
      @card = Current.user.accessible_cards.find_by!(number: params[:id])
    end

    def redirect_if_drafted
      redirect_to card_draft_path(@card) if @card.drafted?
    end

    def card_params
      params.expect(card: [ :title, :description, :image, :due_on, :created_at, :last_active_at ])
    end
end

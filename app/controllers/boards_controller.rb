class BoardsController < ApplicationController
  wrap_parameters :board, include: %i[ name ]

  include FilterScoped

  before_action :set_board, except: %i[ index new create ]

  def index
    set_page_and_extract_portion_from Current.user.boards.ordered_by_recent_activity.includes(creator: :identity)
    fresh_when etag: @page.records
  end

  def show
    if @filter.used?(ignore_boards: true)
      show_filtered_cards
    else
      show_columns
    end
  end

  def new
    @board = Board.new
  end

  def create
    @board = Board.create! board_params

    respond_to do |format|
      format.html { redirect_to board_path(@board) }
      format.json { render :show, status: :created, location: board_path(@board, format: :json) }
    end
  end

  def edit
  end

  def update
    @board.update! board_params

    respond_to do |format|
      format.html { redirect_to edit_board_path(@board), notice: "Saved" }
      format.json { render :show }
    end
  end

  def destroy
    @board.destroy

    respond_to do |format|
      format.html { redirect_to root_path }
      format.json { head :no_content }
    end
  end

  private
    def set_board
      @board = Current.user.boards.find params[:id]
    end

    def show_filtered_cards
      @filter.board_ids = [ @board.id ]
      set_page_and_extract_portion_from @filter.cards
    end

    def show_columns
      cards = @board.cards.awaiting_triage.by_due_date.with_golden_first.preloaded
      set_page_and_extract_portion_from cards
      fresh_when etag: [ @board, @page.records, @user_filtering, Current.account, Date.current ]
    end

    def board_params
      params.expect(board: [ :name ])
    end
end

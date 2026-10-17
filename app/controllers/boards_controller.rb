class BoardsController < ApplicationController
  wrap_parameters :board, include: %i[ name ]

  include StrictQueryParams

  serves_json :index, :show, :create, :update, :destroy

  before_action :set_board, except: %i[ index new create ]

  # The home page lists every board by name; the JSON index pages through them by recent activity.
  def index
    respond_to do |format|
      format.html do
        @boards = Current.user.boards.alphabetically
        if stale? etag: [ @boards, Current.user ]
          @card_counts = Card.where(board: @boards).group(:board_id).count
        end
      end
      format.json do
        set_page_and_extract_portion_from Current.user.boards.ordered_by_recent_activity.includes(:creator)
        fresh_when etag: @page.records
      end
    end
  end

  # Each lane loads its own cards in a frame; a card's save touches the board, so the board
  # stands in for them in the etag. The account and its upgrade URL decide whether "Add a card"
  # is an upgrade link. `due=soon` narrows every lane to the cards due by tomorrow.
  def show
    @due_soon = params[:due] == "soon"
    fresh_when etag: [ @board, Current.user, Current.account, Current.account.upgrade_url, Date.current, @due_soon ]
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

  # The boards list is the only place a browser renames a board, so it goes back there.
  def update
    @board.update! board_params

    respond_to do |format|
      format.html { redirect_to root_path }
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

    def board_params
      params.expect(board: [ :name ])
    end
end

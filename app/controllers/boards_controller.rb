class BoardsController < ApplicationController
  wrap_parameters :board, include: %i[ name ]

  include StrictQueryParams

  serves_json :index, :show, :create, :update, :destroy

  before_action :set_board, except: %i[ index new create ]

  def index
    set_page_and_extract_portion_from Current.user.boards.ordered_by_recent_activity.includes(:creator)
    fresh_when etag: @page.records
  end

  # Each lane loads its own cards in a frame; a card's save touches the board, so the board
  # stands in for them in the etag. The header's account menu offers an upgrade only while
  # there is somewhere to upgrade.
  def show
    fresh_when etag: [ @board, Current.user, Current.account, Current.account.upgrade_url, Date.current ]
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

  def update
    @board.update! board_params

    respond_to do |format|
      format.html { redirect_to board_path(@board) }
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

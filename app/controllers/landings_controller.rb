class LandingsController < ApplicationController
  def show
    @boards = Current.user.boards.ordered_by_recent_activity
    @board_paths = @boards.to_h { |board| [ board.id, board_path(board) ] }
    @default_board_path = board_path(@boards.first) if @boards.any?
  end
end

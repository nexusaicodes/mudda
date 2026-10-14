class My::MenusController < ApplicationController
  # The board switcher: every board and a way to add one, the cross-board views with what
  # each holds, and, on a board, the way to delete it. A card's save touches its board, so the
  # boards stand in for the counts.
  def show
    @boards = Current.user.boards.alphabetically
    @current_board = @boards.find { it.id == params[:board_id].to_i }
    @current_view = params[:view].to_s

    if stale? etag: [ @boards, @current_board, @current_view, Date.current ]
      @views = Filter::VIEWS.map { |view| [ view, Filter.new(Current.user, view.params).cards.count ] }
    end
  end
end

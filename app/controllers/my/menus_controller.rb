class My::MenusController < ApplicationController
  # The board switcher: every board, the cross-board views with what each holds, and a way
  # to add a board. A card's save touches its board, so the boards stand in for the counts.
  def show
    @boards = Current.user.boards.alphabetically
    @current_board_id = params[:board_id].to_i

    if stale? etag: [ @boards, @current_board_id, Date.current ]
      @views = Filter::VIEWS.map { |view| [ view, Filter.new(Current.user, view[:params]).cards.count ] }
    end
  end
end

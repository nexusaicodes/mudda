# The board picker. Choosing a board submits to CardsController#update, which is where a
# card's board actually changes.
class Cards::BoardsController < ApplicationController
  include CardScoped, BrowserOnly

  def edit
    @boards = Current.user.boards.ordered_by_recent_activity
    fresh_when @boards
  end
end

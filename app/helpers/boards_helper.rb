module BoardsHelper
  def link_back_to_board(board, prefer_referrer: [])
    back_link_to board.name, board, action: "click->turbo-navigation#backIfSamePath", prefer_referrer:
  end
end

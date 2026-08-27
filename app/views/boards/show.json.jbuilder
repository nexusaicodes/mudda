json.partial! "boards/board", board: @board

json.columns @board.columns.sorted, partial: "columns/column", as: :column

require_relative "tool"
require_relative "tools/account"
require_relative "tools/boards"
require_relative "tools/cards"
require_relative "tools/notes"

module Mudda::Mcp::Tools
  ALL = [
    Whoami, SearchCards,
    ListBoards, GetBoard, CreateBoard, RenameBoard,
    ListCards, GetCard, CreateCard, UpdateCard,
    ListNotes, AddNote, UpdateNote
  ]
end

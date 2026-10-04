require_relative "tool"
require_relative "tools/account"
require_relative "tools/boards"
require_relative "tools/cards"
require_relative "tools/notes"

module Mudda::Mcp::Tools
  ALL = [
    Whoami, SearchCards,
    ListBoards, GetBoard, CreateBoard, RenameBoard, DeleteBoard,
    ListCards, GetCard, CreateCard, UpdateCard, DeleteCard,
    ListNotes, AddNote, UpdateNote, DeleteNote
  ]

  # The tools a credential holding these scopes can use. The API refuses the rest anyway; not
  # offering them keeps an agent from planning around a call it can't make.
  def self.granted(scopes)
    ALL.select { |tool| scopes.include?(tool.scope) }
  end
end

module NotesHelper
  def new_note_placeholder(card)
    if card.notes.empty?
      "Next, add some notes, context, pictures, or video about this…"
    else
      "Type your note…"
    end
  end
end

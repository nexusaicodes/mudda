module NotesHelper
  def notes_tag(card, &)
    turbo_frame_tag dom_id(card, :notes),
      class: "notes gap center",
      style: "--card-color: #{card.color}",
      role: "group",
      aria: { label: "Notes" }, &
  end

  def new_note_placeholder(card)
    if card.notes.empty?
      "Next, add some notes, context, pictures, or video about this…"
    else
      "Type your note…"
    end
  end
end

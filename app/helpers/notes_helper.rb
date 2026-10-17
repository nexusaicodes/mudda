module NotesHelper
  def notes_tag(card, &)
    turbo_frame_tag dom_id(card, :notes),
      class: "notes flex flex-col gap-4 w-full max-w-3xl mx-auto mt-6 text-start",
      style: "--card-color: #{card.color}",
      role: "group",
      aria: { label: t("cards.notes.label") }, &
  end

  def new_note_placeholder(card)
    if card.notes.empty?
      t("cards.notes.first_placeholder")
    else
      t("cards.notes.placeholder")
    end
  end
end

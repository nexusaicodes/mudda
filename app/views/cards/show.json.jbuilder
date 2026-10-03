json.partial! "cards/card", card: @card

json.steps @card.steps, partial: "cards/steps/step", as: :step

# The most recent notes only — see Card::Notable. notes_url pages through the whole log.
json.notes @card.latest_notes, partial: "cards/notes/note", as: :note
json.notes_truncated @card.notes_truncated?

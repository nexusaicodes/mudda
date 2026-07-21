module EventsHelper
  def event_action_icon(event)
    case event.action
    when "note_created"
      "comment"
    when "card_title_changed"
      "rename"
    when "card_board_changed", "card_triaged"
      "move"
    else
      "person"
    end
  end
end

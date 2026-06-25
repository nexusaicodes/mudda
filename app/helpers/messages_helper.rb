module MessagesHelper
  def messages_tag(card, &)
    turbo_frame_tag dom_id(card, :messages),
      class: "notes gap center",
      style: "--card-color: #{card.color}",
      role: "group",
      aria: { label: "Notes" }, &
  end
end

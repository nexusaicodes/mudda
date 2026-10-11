module CardsHelper
  def card_article_tag(card, id: dom_id(card, :article), data: {}, **options, &block)
    classes = [
      options.delete(:class),
      ("golden-effect" if card.golden?),
      ("card--active" if card.active?)
    ].compact.join(" ")

    data[:drag_and_drop_top] = true if card.golden? && !card.closed? && !card.backlogged?

    tag.article \
      id: id,
      style: "--card-color: #{card.color}; view-transition-name: #{id}",
      class: classes,
      data: data,
      **options,
      &block
  end

  def card_title_tag(card)
    [
      card.title,
      "added by #{card.creator.name}",
      "in #{card.board.name}"
    ].join(" ")
  end

  def card_due_label(card)
    if card.due_on.year == Date.current.year
      card.due_on.strftime("%b %-d")
    else
      card.due_on.strftime("%b %-d, %Y")
    end
  end

  # One tone for a due date wherever it shows: only a card that is late or due within a day asks
  # for attention.
  def card_due_tone(card)
    days = card.days_until_due

    if days.negative?
      "overdue"
    elsif days <= 1
      "soon"
    else
      "later"
    end
  end

  # Relative while it's close, then the date: "Overdue 2d", "Today", "Tomorrow", "Fri", "Oct 24".
  def card_due_relative_label(card)
    days = card.days_until_due

    case days
    when ...0 then "Overdue #{-days}d"
    when 0    then "Today"
    when 1    then "Tomorrow"
    when 2..6 then card.due_on.strftime("%a")
    else           card_due_label(card)
    end
  end

  def card_social_tags(card)
    tag.meta(property: "og:title", content: "#{card.title} | #{card.board.name}") +
    tag.meta(property: "og:description", content: format_excerpt(card&.description, length: 200)) +
    tag.meta(property: "og:image", content: "#{request.base_url}/app-icon.png") +
    tag.meta(property: "og:url", content: board_card_url(card.board, card))
  end
end

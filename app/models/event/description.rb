class Event::Description
  include ActionView::Helpers::TagHelper
  include ERB::Util

  attr_reader :event, :user

  def initialize(event, user)
    @event = event
    @user = user
  end

  def to_html
    to_sentence(creator_tag, card_title_tag).html_safe
  end

  def to_plain_text
    to_sentence(creator_name, quoted(card.title)).html_safe
  end

  private
    def to_sentence(creator, card_title)
      if event.action.note_created?
        note_sentence(creator, card_title)
      else
        action_sentence(creator, card_title)
      end
    end

    def creator_tag
      tag.span data: { creator_id: event.creator.id } do
        tag.span("You", data: { only_visible_to_you: true }) +
        tag.span(event.creator.name, data: { only_visible_to_others: true })
      end
    end

    def card_title_tag
      tag.span card.title, class: "txt-underline"
    end

    def creator_name
      h event.creator.name
    end

    def quoted(text)
      h %("#{text}")
    end

    def card
      @card ||= event.action.note_created? ? event.eventable.card : event.eventable
    end

    def note_sentence(creator, card_title)
      "#{creator} added a note to #{card_title}"
    end

    def action_sentence(creator, card_title)
      case event.action
      when "card_published"
        "#{creator} added #{card_title}"
      when "card_title_changed"
        renamed_sentence(creator, card_title)
      when "card_board_changed"
        moved_sentence(creator, card_title)
      when "card_triaged"
        triaged_sentence(creator, card_title)
      end
    end

    def renamed_sentence(creator, card_title)
      %(#{creator} renamed #{card_title} (was: "#{old_title}"))
    end

    def moved_sentence(creator, card_title)
      %(#{creator} moved #{card_title} to "#{new_location}")
    end

    def triaged_sentence(creator, card_title)
      %(#{creator} moved #{card_title} to "#{column}")
    end

    def old_title
      h event.particulars.dig("particulars", "old_title")
    end

    def new_location
      h event.particulars.dig("particulars", "new_board")
    end

    def column
      h event.particulars.dig("particulars", "column")
    end
end

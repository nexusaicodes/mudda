class Notifier::CardEventNotifier < Notifier
  delegate :creator, to: :source

  private
    def recipients
      case source.action
      when "card_assigned"
        source.assignees.excluding(creator)
      when "card_published"
        card.assignees.excluding(creator)
      when "comment_created"
        card.watchers.without(creator, *source.eventable.scan_mentionees)
      else
        []
      end
    end

    def card
      source.eventable
    end
end

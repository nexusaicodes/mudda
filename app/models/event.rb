class Event < ApplicationRecord
  belongs_to :creator, class_name: "User"
  belongs_to :eventable, polymorphic: true

  after_create -> { eventable.event_was_created(self) }
end

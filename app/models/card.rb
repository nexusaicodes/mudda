class Card < ApplicationRecord
  include Attachments, Colored, Notable,
    Due, Eventable, Golden, Multistep, Promptable,
    Searchable, Triageable

  belongs_to :board
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_one_attached :image, dependent: :purge_later

  has_rich_text :description

  before_save :set_default_title
  before_create :assign_number
  before_update :renumber_for_new_board, if: :board_id_changed?

  after_save   -> { board.touch }
  after_touch  -> { board.touch }
  after_update :handle_board_change, if: :saved_change_to_board_id?

  scope :reverse_chronologically, -> { order created_at:     :desc, id: :desc }
  scope :chronologically,         -> { order created_at:     :asc,  id: :asc  }
  scope :latest,                  -> { order last_active_at: :desc, id: :desc }
  scope :by_due_date,             -> { order Arel.sql("cards.due_on IS NULL, CASE WHEN cards.due_on < '#{Date.current.to_fs(:db)}' THEN 1 ELSE 0 END, cards.due_on ASC, cards.id ASC") }
  scope :with_users,              -> { preload(creator: [ :avatar_attachment, :account ]) }
  scope :preloaded,               -> { with_users.preload(:column, :steps, :image_attachment, board: [ :columns ]).with_rich_text_description_and_embeds }

  scope :indexed_by, ->(index) do
    case index
    when "golden" then golden
    else all
    end
  end

  scope :sorted_by, ->(sort) do
    case sort
    when "newest" then reverse_chronologically
    when "oldest" then chronologically
    when "latest" then latest
    else latest
    end
  end

  def card
    self
  end

  def to_param
    number.to_s
  end

  def filled?
    title.present? || description.present?
  end

  def accessible_to?(user)
    user&.account_id == board.account_id
  end

  private
    def set_default_title
      self.title = "Untitled" if title.blank?
    end

    def handle_board_change
      old_board = Board.find_by(id: board_id_before_last_save)

      transaction do
        update! column: board.triage_column
        rehome_events
        track_board_change_event(old_board.name)
      end
    end

    # Events are indexed by board, so a card's own events and its notes' follow it rather
    # than staying behind on the board it left.
    def rehome_events
      events.update_all(board_id: board_id)
      Event.where(eventable: notes).update_all(board_id: board_id)
    end

    def track_board_change_event(old_board_name)
      track_event "board_changed", particulars: { old_board: old_board_name, new_board: board.name }
    end

    # Numbers run per board, so a card's number and its board together address it.
    def assign_number
      self.number ||= next_number
    end

    # In the same UPDATE as the board change: the destination may already be using this
    # card's number, and [board_id, number] is unique.
    def renumber_for_new_board
      self.number = next_number
    end

    def next_number
      board.with_lock { board.increment!(:cards_count).cards_count }
    end
end

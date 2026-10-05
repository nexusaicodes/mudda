class Card < ApplicationRecord
  include Attachments, Colored, Notable,
    Due, Eventable, Golden, Multistep, Promptable,
    Searchable, Triageable

  belongs_to :board
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_rich_text :description

  before_validation :land_in_destination_triage, on: :update, if: :board_id_changed?
  before_save :set_default_title
  before_create :claim_card_slot, :assign_number
  before_update :renumber_for_new_board, if: :board_id_changed?

  after_save   -> { board.touch }
  after_touch  -> { board.touch }
  after_update :track_board_change, if: -> { tracked_change?("board_id") }

  scope :reverse_chronologically, -> { order created_at:     :desc, id: :desc }
  scope :chronologically,         -> { order created_at:     :asc,  id: :asc  }
  scope :latest,                  -> { order last_active_at: :desc, id: :desc }
  scope :by_due_date,             -> { order Arel.sql("cards.due_on IS NULL, CASE WHEN cards.due_on < '#{Date.current.to_fs(:db)}' THEN 1 ELSE 0 END, cards.due_on ASC, cards.id ASC") }
  scope :with_users,              -> { preload(creator: [ :avatar_attachment, :account ]) }
  scope :preloaded,               -> { with_users.preload(:column, :steps, board: [ :columns ]).with_rich_text_description_and_embeds }

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

    # A move names where the card ends up. A lane named alongside the board is kept, and
    # column_on_its_board refuses one from anywhere else; with no lane named, the card starts
    # over in the destination's Triage. Settled before validation, so the move is one UPDATE.
    def land_in_destination_triage
      self.column = board.triage_column unless column_id_changed?
    end

    def track_board_change
      track_event "board_changed", particulars: { old_board: Board.find_by(id: tracked_change_was("board_id"))&.name, new_board: board.name }
    end

    # Raised rather than thrown, so save answers false with the error on the card and save!
    # raises RecordInvalid, which JSON clients receive as the usual 422 envelope.
    def claim_card_slot
      unless board.account.claim_card_slot
        errors.add :base, "This account has used all #{board.account.card_limit} of its cards"
        raise ActiveRecord::RecordInvalid, self
      end
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

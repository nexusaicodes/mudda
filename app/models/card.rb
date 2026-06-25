class Card < ApplicationRecord
  include Attachments, Broadcastable, Colored, Notable,
    Due, Eventable, Golden, Multistep, Pinnable, Promptable,
    Searchable, Statuses, Storage::Tracked, Triageable

  belongs_to :account, default: -> { board.account }
  belongs_to :board
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_one_attached :image, dependent: :purge_later

  has_rich_text :description

  before_save :set_default_title, if: :published?
  before_create :assign_number

  after_save   -> { board.touch }, if: :published?
  after_touch  -> { board.touch }, if: :published?
  after_update :handle_board_change, if: :saved_change_to_board_id?

  scope :reverse_chronologically, -> { order created_at:     :desc, id: :desc }
  scope :chronologically,         -> { order created_at:     :asc,  id: :asc  }
  scope :latest,                  -> { order last_active_at: :desc, id: :desc }
  scope :with_users,              -> { preload(creator: [ :avatar_attachment, :account ]) }
  scope :preloaded,               -> { with_users.preload(:column, :steps, :goldness, :image_attachment, board: [ :columns ]).with_rich_text_description_and_embeds }

  scope :indexed_by, ->(index) do
    case index
    when "golden" then golden
    when "draft" then drafted
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

  def move_to(new_board)
    transaction do
      card.update!(board: new_board)
      card.events.update_all(board_id: new_board.id)
      Event.where(eventable: card.notes).update_all(board_id: new_board.id)
    end
  end

  def filled?
    title.present? || description.present?
  end

  def accessible_to?(user)
    user&.account_id == account_id
  end

  private
    def set_default_title
      self.title = "Untitled" if title.blank?
    end

    def handle_board_change
      old_board = account.boards.find_by(id: board_id_before_last_save)

      transaction do
        update! column: board.triage_column
        track_board_change_event(old_board.name)
      end
    end

    def track_board_change_event(old_board_name)
      track_event "board_changed", particulars: { old_board: old_board_name, new_board: board.name }
    end

    def assign_number
      self.number ||= account.increment!(:cards_count).cards_count
    end
end

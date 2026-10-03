module Card::Triageable
  extend ActiveSupport::Concern

  # A card always lives in exactly one column. The board's fixed lanes —
  # Triage, Backlog, Todo, Doing, Done — are all real Column rows; column_id is
  # the single source of truth. There are no separate lifecycle states, and each
  # predicate below has a scope that says the same thing in SQL.

  TRIAGE_COLUMN   = "Triage"
  BACKLOG_COLUMN  = "Backlog"
  DOING_COLUMN    = "Doing"
  DONE_COLUMN     = "Done"

  included do
    belongs_to :column, touch: true

    before_validation :assign_default_column, on: :create
    validate :column_on_its_board
    after_update :track_triage_event, if: -> { tracked_change?("column_id") }

    scope :in_column_named,     ->(*names) { joins(:column).where(columns: { name: names }) }
    scope :not_in_column_named, ->(*names) { joins(:column).where.not(columns: { name: names }) }

    scope :closed,          -> { in_column_named(DONE_COLUMN) }
    scope :open,            -> { not_in_column_named(DONE_COLUMN) }
    scope :postponed,       -> { in_column_named(BACKLOG_COLUMN) }
    scope :awaiting_triage, -> { in_column_named(TRIAGE_COLUMN) }
    scope :triaged,         -> { not_in_column_named(TRIAGE_COLUMN) }
    scope :active,          -> { not_in_column_named(DONE_COLUMN, BACKLOG_COLUMN) }
  end

  def closed?
    column&.name == DONE_COLUMN
  end

  def open?
    !closed?
  end

  def postponed?
    column&.name == BACKLOG_COLUMN
  end

  def awaiting_triage?
    column&.name == TRIAGE_COLUMN
  end

  def triaged?
    !awaiting_triage?
  end

  def active?
    !closed? && !postponed?
  end

  def triage_into(column)
    update! column: column
  end

  private
    def assign_default_column
      self.column ||= board&.triage_column
    end

    # Every door that moves a card — the drop target, the pickers, a PUT, the console — meets
    # this, so a card can never sit on one board in another board's lane.
    def column_on_its_board
      if column && column.board_id != board_id
        errors.add :column, "must belong to the card's board"
      end
    end

    # Every lane change is a triage, whichever route asked for it: the drag-and-drop target,
    # the column picker, a PUT to the card with a column_id, or the move into the destination
    # board's Triage on a reparent.
    def track_triage_event
      track_event "triaged", particulars: { column: column.name }
    end
end

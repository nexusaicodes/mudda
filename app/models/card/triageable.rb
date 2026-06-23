module Card::Triageable
  extend ActiveSupport::Concern

  # A card always lives in exactly one column. The board's fixed lanes —
  # Triage, Backlog, Todo, Doing, Done — are all real Column rows; column_id is
  # the single source of truth. There are no separate lifecycle states.
  #
  # The instance predicates report a single card's column placement regardless of
  # its draft/published status. The scopes additionally filter to published cards,
  # since they back lists and counts that exclude drafts; a draft sitting in a lane
  # therefore matches the predicate but not the scope.
  TRIAGE_COLUMN   = "Triage"
  BACKLOG_COLUMN  = "Backlog"
  DONE_COLUMN     = "Done"

  included do
    belongs_to :column, touch: true

    before_validation :assign_default_column, on: :create

    scope :in_column_named,     ->(*names) { joins(:column).where(columns: { name: names }) }
    scope :not_in_column_named, ->(*names) { joins(:column).where.not(columns: { name: names }) }

    scope :closed,          -> { in_column_named(DONE_COLUMN) }
    scope :open,            -> { not_in_column_named(DONE_COLUMN) }
    scope :postponed,       -> { published.in_column_named(BACKLOG_COLUMN) }
    scope :awaiting_triage, -> { published.in_column_named(TRIAGE_COLUMN) }
    scope :triaged,         -> { published.not_in_column_named(TRIAGE_COLUMN) }
    scope :active,          -> { published.not_in_column_named(DONE_COLUMN, BACKLOG_COLUMN) }
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
    published? && !closed? && !postponed?
  end

  def triage_into(column)
    raise "The column must belong to the card board" unless board == column.board

    transaction do
      update! column: column
      track_event "triaged", particulars: { column: column.name }
    end
  end

  private
    def assign_default_column
      self.column ||= board&.triage_column
    end
end

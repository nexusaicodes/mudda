module Board::Triageable
  extend ActiveSupport::Concern

  # Every board has the same five fixed lanes, in this order. They are all real
  # Column rows — there are no separate lifecycle states. Names are fixed (only
  # color is editable); Card section predicates key off these names.
  DEFAULT_COLUMNS = [
    { name: "Triage",  color: "var(--color-card-1)" },
    { name: "Backlog", color: "var(--color-card-2)" },
    { name: "Todo",    color: "var(--color-card-3)" },
    { name: "Doing",   color: "var(--color-card-5)" },
    { name: "Done",    color: "var(--color-card-4)" }
  ].freeze

  included do
    has_many :columns, dependent: :destroy

    after_create :create_default_columns
  end

  def triage_column
    columns.find_by(name: Card::Triageable::TRIAGE_COLUMN) || columns.sorted.first
  end

  def done_column
    columns.find_by(name: Card::Triageable::DONE_COLUMN)
  end

  private
    def create_default_columns
      DEFAULT_COLUMNS.each { |attributes| columns.create!(attributes) }
    end
end

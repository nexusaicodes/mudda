# The question a card list answers — which of the user's cards, in what order — read from the
# query string. A filter lives for one request and is never stored.
class Filter
  include ActiveModel::Validations

  PERMITTED_PARAMS = [
    :indexed_by,
    :sorted_by,
    :creation,
    :due,
    :lane,
    card_ids: [],
    column_ids: [],
    board_ids: [],
    terms: []
  ]

  DEFAULTS = { indexed_by: "all", sorted_by: "latest" }

  INDEXES = %w[ all golden ]
  SORTS = %w[ latest newest oldest ]
  DUES = %w[ soon ]
  LANES = Board::Triageable::DEFAULT_COLUMNS.map { |column| column[:name].downcase }

  # The cross-board views the board switcher offers: each is a filter with a name.
  View = Data.define(:key, :icon, :params) do
    def name
      I18n.t("filters.views.#{key}", lane: params[:lane] && I18n.t("lanes.#{params[:lane]}"))
    end

    def [](attribute)
      public_send(attribute)
    end
  end

  VIEWS = [
    View.new(key: :due_soon, icon: "bell-alert",    params: { due: "soon" }),
    View.new(key: :doing,    icon: "bolt",          params: { lane: Card::Triageable::DOING_COLUMN.downcase }),
    View.new(key: :golden,   icon: "golden-ticket", params: { indexed_by: "golden" })
  ].freeze

  attr_reader :creator, :indexed_by, :sorted_by, :creation, :due, :lane, :terms, :card_ids, :column_ids, :board_ids

  validates :indexed_by, inclusion: { in: INDEXES }
  validates :sorted_by, inclusion: { in: SORTS }
  validates :due, inclusion: { in: DUES }, allow_nil: true
  validates :lane, inclusion: { in: LANES }, allow_nil: true
  validate :creation_is_a_known_window

  def initialize(creator, params = {})
    params = params.to_h.symbolize_keys.with_defaults(DEFAULTS)

    @creator    = creator
    @indexed_by = params[:indexed_by].to_s
    @sorted_by  = params[:sorted_by].to_s
    @creation   = params[:creation].presence
    @due        = params[:due].presence
    @lane       = params[:lane].presence&.downcase
    @terms      = Array(params[:terms]).compact_blank
    @card_ids   = Array(params[:card_ids]).compact_blank.uniq
    @column_ids = Array(params[:column_ids]).compact_blank.uniq
    @board_ids  = Array(params[:board_ids]).compact_blank.uniq
  end

  # A due-soon list reads most overdue first unless another order was asked for.
  def cards
    @cards ||= begin
      result = creator.accessible_cards.preloaded
      result = result.indexed_by(indexed_by)
      result = result.where(id: card_ids) if card_ids.present?
      result = result.where(board: boards) if board_ids.present?
      result = result.where(cards: { created_at: creation_window }) if creation
      result = terms.reduce(result) { |result, term| result.mentioning(term, user: creator) }
      result = result.where(column_id: column_ids) if column_ids.present?
      result = result.in_column_named(lane.capitalize) if lane
      result = result.due_soon if due == "soon"
      result = due && sorted_by == DEFAULTS[:sorted_by] ? result.most_overdue_first : result.sorted_by(sorted_by)

      result.distinct
    end
  end

  def boards
    @boards ||= creator.boards.where(id: board_ids)
  end

  def single_board
    boards.first if board_ids.one?
  end

  def boards_label
    if boards.any?
      boards.map(&:name).to_sentence
    else
      creator.boards.one? ? creator.boards.first.name : I18n.t("filters.all_boards")
    end
  end

  # The name of the view this filter is, if it is exactly one of them.
  def view_name
    VIEWS.find { |view| Filter.new(creator, view.params).as_params == as_params }&.name
  end

  def as_params
    {
      indexed_by: indexed_by, sorted_by: sorted_by, creation: creation, due: due, lane: lane,
      terms: terms, card_ids: card_ids, column_ids: column_ids, board_ids: board_ids
    }.compact_blank.reject { |name, value| DEFAULTS[name] == value }
  end

  private
    def creation_window
      TimeWindowParser.parse(creation)
    end

    def creation_is_a_known_window
      if creation && creation_window.nil?
        errors.add :creation, :inclusion
      end
    end
end

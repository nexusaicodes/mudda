module Filter::Views
  extend ActiveSupport::Concern

  # The cross-board views the board switcher offers: each is a filter with a name.
  VIEWS = [
    { name: "Due today & tomorrow", icon: "bell-alert",    params: { due: "soon" } },
    { name: "Doing everywhere",     icon: "bolt",          params: { lane: "doing" } },
    { name: "Golden",               icon: "golden-ticket", params: { indexed_by: "golden" } }
  ].freeze

  # The name of the view this filter is, if it is exactly one of them.
  def view_name
    VIEWS.find { |view| self.class.normalize_params(view[:params]) == self.class.normalize_params(as_params) }&.dig(:name)
  end
end

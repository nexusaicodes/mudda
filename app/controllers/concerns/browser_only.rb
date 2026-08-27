# Endpoints that exist for the browser alone: they render screens and turbo streams, and the
# work behind them is reachable over JSON by updating the record itself. JSON is refused
# before the action runs, so a JSON request is a 406 rather than a mutation followed by one.
module BrowserOnly
  extend ActiveSupport::Concern

  included do
    before_action :refuse_json
  end

  private
    def refuse_json
      raise ActionController::UnknownFormat if request.format.json?
    end
end

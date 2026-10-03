# JSON is something an endpoint offers, not something it has to remember to refuse. Each
# controller names the actions it answers in JSON, and a JSON request to anything else is a 406
# before the action runs — so an endpoint that never thought about JSON can't write a record and
# then fail to render it.
module ServesJson
  extend ActiveSupport::Concern

  included do
    class_attribute :json_actions, default: []

    before_action :refuse_unserved_json
  end

  class_methods do
    def serves_json(*actions)
      self.json_actions = json_actions + actions.map(&:to_s)
    end
  end

  private
    def refuse_unserved_json
      if request.format.json? && json_actions.exclude?(action_name)
        raise ActionController::UnknownFormat
      end
    end
end

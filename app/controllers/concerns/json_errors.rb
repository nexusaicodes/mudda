# Renders the errors a JSON client needs as JSON, in the shape CardsController already
# returns: { "errors": { "attribute": [ "message" ] } }.
#
# Non-JSON requests re-raise, so the browser keeps Rails' usual error pages. A handler that
# raises propagates out of process_action rather than re-entering rescue_with_handler.
module JsonErrors
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound,      with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid,       with: :render_record_invalid
    rescue_from Card::Triageable::WrongBoardError, with: :render_wrong_board
  end

  private
    def render_not_found(error)
      render_error error, status: :not_found do
        { base: [ "Not found" ] }
      end
    end

    def render_record_invalid(error)
      render_error error, status: :unprocessable_entity do
        error.record.errors
      end
    end

    def render_wrong_board(error)
      render_error error, status: :unprocessable_entity do
        { column: [ error.message ] }
      end
    end

    def render_error(error, status:)
      if request.format.json?
        render json: { errors: yield }, status: status
      else
        raise error
      end
    end
end

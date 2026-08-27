# Renders the errors a JSON client needs as JSON, in one shape:
# { "errors": { "attribute": [ "message" ] } }
#
# Every failure a JSON client can see uses it: the refusals Authentication and Authorization
# render from callbacks as much as the record errors rescued here. One shape means a client
# never branches on the response to find out what went wrong.
#
# Non-JSON requests re-raise, so the browser keeps Rails' usual error pages. A handler that
# raises propagates out of process_action rather than re-entering rescue_with_handler.
module JsonErrors
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid,  with: :render_record_invalid
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

    # Unlike the rescue_from handlers, these are called directly from a before_action that
    # has already decided the request is JSON, so there is no error to re-raise.
    def render_unauthorized(message)
      render_json_errors({ base: [ message ] }, status: :unauthorized)
    end

    def render_forbidden(message)
      render_json_errors({ base: [ message ] }, status: :forbidden)
    end

    def render_error(error, status:)
      if request.format.json?
        render_json_errors yield, status: status
      else
        raise error
      end
    end

    def render_json_errors(errors, status:)
      render json: { errors: errors }, status: status
    end
end

# Renders the errors a JSON client needs as JSON, in one shape:
# { "errors": { "attribute": [ "message" ] } }
#
# Every failure a JSON client can see uses it: the refusals Authentication and Authorization
# render from callbacks as much as the errors rescued here, and whatever escapes a controller
# altogether — an unknown route, a forged request, a crash — is rendered in the same shape by
# JsonPublicExceptions. One shape means a client never branches on the response to find out
# what went wrong.
#
# Writes therefore use the bang methods and let the rescue do the rendering, rather than
# branching on a return value and building the envelope by hand.
#
# Non-JSON requests re-raise, so the browser keeps Rails' usual error pages. A handler that
# raises propagates out of process_action rather than re-entering rescue_with_handler.
module JsonErrors
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound,      with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid,       with: :render_record_invalid
    rescue_from ActiveRecord::NotNullViolation,    with: :render_not_null_violation
    rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
    rescue_from ActionController::UnknownFormat,    with: :render_unknown_format
  end

  private
    def render_not_found(error)
      render_error error, status: :not_found do
        { base: [ "Not found" ] }
      end
    end

    # A null sent for a column the database requires is the client's mistake, not a crash —
    # and it names the column whichever model it belongs to, a step saved with its card or not.
    def render_not_null_violation(error)
      render_error error, status: :unprocessable_entity do
        { error.message[/NOT NULL constraint failed: \w+\.(\w+)/, 1] || :base => [ "can't be blank" ] }
      end
    end

    def render_parameter_missing(error)
      render_error error, status: :bad_request do
        { error.param => [ "is required" ] }
      end
    end

    def render_unknown_format(error)
      render_error error, status: :not_acceptable do
        { base: [ "This endpoint does not answer JSON" ] }
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

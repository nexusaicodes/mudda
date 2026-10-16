# Renders the errors a JSON client needs as JSON, in one shape:
# { "errors": { "attribute": [ "message" ] }, "request_id": "…" }
#
# The request id is the reference a client quotes to find the request in the logs.
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
    # The last matching handler wins, so the most general come first.
    rescue_from StandardError,                     with: :render_internal_error
    # Ahead of its subclasses (RecordNotUnique, NotNullViolation), which have handlers of their own.
    rescue_from ActiveRecord::StatementInvalid,    with: :render_statement_invalid
    rescue_from ActiveRecord::RecordNotFound,      with: :render_not_found
    rescue_from ActiveRecord::RecordNotUnique,     with: :render_conflict
    rescue_from ActiveRecord::RecordInvalid,       with: :render_record_invalid
    rescue_from ActiveRecord::NotNullViolation,    with: :render_not_null_violation
    rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
    rescue_from ActionController::UnknownFormat,    with: :render_unknown_format
  end

  private
    # A bug, reported once with the request id the client is shown. A query a view ran is judged
    # by its own failure. An exception Rails maps to
    # a 4xx (a forged request, a malformed body) keeps that status through JsonPublicExceptions.
    def render_internal_error(error)
      if error.is_a?(ActionView::Template::Error) && error.cause.is_a?(ActiveRecord::StatementInvalid)
        render_statement_invalid error.cause
      elsif request.format.json? && ActionDispatch::ExceptionWrapper.status_code_for_exception(error.class.name) == 500
        Rails.error.report error, handled: false, source: "application.action_controller"
        render_json_errors({ base: [ "Internal server error" ] }, status: :internal_server_error)
      else
        raise error
      end
    end

    def render_not_found(error)
      render_error error, status: :not_found do
        { base: [ "Not found" ] }
      end
    end

    # Two writes racing for the same unique value: the one that lost can be retried.
    def render_conflict(error)
      render_error error, status: :conflict do
        { base: [ "Conflicts with a concurrent change; try again" ] }
      end
    end

    # A search FTS5 can't parse is the client's to fix; any other statement failure is a bug.
    def render_statement_invalid(error)
      if error.message.match?(/fts5: syntax error/i)
        render_error(Search::Query::Invalid.new("invalid search"), status: :unprocessable_entity) { { q: [ "is not a valid search" ] } }
      else
        render_internal_error error
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
      render json: { errors: errors, request_id: request.request_id }, status: status
    end
end

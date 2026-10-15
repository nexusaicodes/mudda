# Where the hosting platform sends its signed messages (see Platform::Message). The signature is
# the only credential: no session or token is read, so nothing the owner holds can reach it.
# Without platform keys configured, as when self-hosting, it isn't there at all.
class Platform::MessagesController < ActionController::API
  # Its own store, as the sign-in rate limit keeps one; see Sessions::PasswordsController.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  rate_limit to: 60, within: 1.minute, store: RATE_LIMIT_STORE,
    with: -> { render_error "Too many messages; try again later", status: :too_many_requests }

  before_action :ensure_enabled

  def create
    message = Platform::Message.verify(request.raw_post.to_s, host: Platform::Message.audience(request.host))

    if state = message.apply(Account.sole)
      WebhookDelivery.deliver_due_later
      render json: state
    else
      head :no_content
    end
  rescue Platform::Message::Invalid => error
    render_error error.message, status: :unauthorized
  end

  private
    def ensure_enabled
      head :not_found unless Platform::Message.enabled?
    end

    def render_error(message, status:)
      render json: { errors: { message: [ message ] } }, status: status
    end
end

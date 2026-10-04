# The tokens scripts and agents sign in with, managed from the browser — so a deployment with
# no shell (a cloud tenant) can still mint and revoke them. A token's own credential is shown
# once, when it is minted, and never again.
class My::TokensController < ApplicationController
  require_browser_session

  def index
    @tokens = tokens
    @token = Current.user.sessions.token.new(scopes: Session::DEFAULT_SCOPES)
  end

  def create
    @token = Current.user.sessions.token.new(token_params.merge(user_agent: request.user_agent, ip_address: request.remote_ip))

    if valid_with_scopes_chosen? && @token.save
      render :create, status: :created
    else
      @tokens = tokens
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    tokens.find(params[:id]).destroy!
    redirect_to my_tokens_path, notice: "Token revoked"
  end

  private
    def tokens
      Current.user.sessions.token.order(created_at: :desc)
    end

    def token_params
      params.expect(token: [ :label, scopes: [] ])
    end

    # Here the scopes are chosen one by one, so a token with none ticked is a mistake to point
    # out — alongside anything else wrong with it — rather than a request for
    # Session::DEFAULT_SCOPES.
    def valid_with_scopes_chosen?
      @token.validate
      @token.errors.add :base, "Choose at least one thing the token may do" if token_params[:scopes].to_a.compact_blank.empty?
      @token.errors.none?
    end
end

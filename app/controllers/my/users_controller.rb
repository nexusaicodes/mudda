class My::UsersController < ApplicationController
  serves_json :show

  # Who a token belongs to, and what it was granted, is something any token may ask: /mcp asks
  # it before every call to learn which tools to offer.
  allow_any_token_scope only: :show

  def show
    @user = Current.user
  end
end

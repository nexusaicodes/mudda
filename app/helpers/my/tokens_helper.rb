module My::TokensHelper
  # What each of Session::SCOPES lets a token do, as the API tokens page and the OAuth consent
  # screen both put it (tokens.scopes.* in config/locales).
  def scope_descriptions(scopes = Session::SCOPES)
    (Session::SCOPES & scopes).index_with { |scope| t("tokens.scopes.#{scope}") }
  end

  def token_expiry(token)
    if token.expires_at.past?
      t("tokens.expiry.expired")
    elsif token.oauth?
      t("tokens.expiry.unless_used", date: l(token.expires_at.to_date, format: :app_long))
    else
      t("tokens.expiry.expires", date: l(token.expires_at.to_date, format: :app_long))
    end
  end
end

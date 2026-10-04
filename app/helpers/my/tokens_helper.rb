module My::TokensHelper
  # What each of Session::SCOPES lets a token do, as the API tokens page and the OAuth consent
  # screen both put it.
  SCOPE_DESCRIPTIONS = {
    "read" => "Read boards, cards, and notes",
    "write" => "Create and change them",
    "delete" => "Delete them — permanently"
  }

  def scope_descriptions(scopes = Session::SCOPES)
    SCOPE_DESCRIPTIONS.slice(*scopes)
  end

  def token_expiry(token)
    if token.expires_at.past?
      "expired"
    elsif token.oauth?
      "expires #{token.expires_at.to_date.to_fs(:long)} unless used"
    else
      "expires #{token.expires_at.to_date.to_fs(:long)}"
    end
  end
end

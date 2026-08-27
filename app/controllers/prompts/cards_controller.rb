# The #-mention autocomplete: a fragment for the text editor, not a card index.
class Prompts::CardsController < ApplicationController
  include BrowserOnly

  MAX_RESULTS = 10

  def index
    @cards = if filter_param.present?
      prepending_exact_matches_by_number(search_cards)
    else
      published_cards.latest
    end

    if stale? etag: @cards
      render layout: false
    end
  end

  private
    def filter_param
      params[:filter]
    end

    def search_cards
      published_cards
        .mentioning(params[:filter], user: Current.user)
        .reverse_chronologically
        .limit(MAX_RESULTS)
    end

    def published_cards
      Current.user.accessible_cards
    end

    # Numbers run per board, so a number can match one card on each of them.
    def prepending_exact_matches_by_number(cards)
      published_cards.where(number: params[:filter]).to_a + cards
    end
end

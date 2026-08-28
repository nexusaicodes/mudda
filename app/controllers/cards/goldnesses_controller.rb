# The star button. Goldness is a boolean column on the card, so everywhere but the browser
# sets it with a PUT to the card itself (see CardsController).
class Cards::GoldnessesController < ApplicationController
  include CardScoped, BrowserOnly

  def create
    @card.gild
    render_card_replacement
  end

  def destroy
    @card.ungild
    render_card_replacement
  end
end

# The pin button. Pinned is a boolean column on the card, so everywhere but the browser
# sets it with a PUT to the card itself (see CardsController).
class Cards::PinsController < ApplicationController
  include CardScoped

  def create
    @card.pin
    render_card_replacement
  end

  def destroy
    @card.unpin
    render_card_replacement
  end
end

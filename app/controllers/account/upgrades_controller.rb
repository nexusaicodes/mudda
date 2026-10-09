# Hands the signed-in owner to the platform's upgrade page (MUDDA_UPGRADE_URL), passing on the
# billing (monthly or yearly) they picked. The platform's "Go Premium" sends a returning
# customer here, so signing in to their board is how they show it's theirs; a signed-out
# visitor signs in first and comes back. A board with no upgrade URL already has unlimited cards.
class Account::UpgradesController < ApplicationController
  BILLINGS = %w[ monthly yearly ].freeze

  def show
    if upgrade_url = Current.account.upgrade_url
      redirect_to with_billing(upgrade_url), allow_other_host: true
    else
      redirect_to root_path, notice: "This board already has unlimited cards"
    end
  end

  private
    def with_billing(url)
      if BILLINGS.include?(params[:billing])
        uri = URI(url)
        uri.query = URI.encode_www_form(URI.decode_www_form(uri.query.to_s) << [ "billing", params[:billing] ])
        uri.to_s
      else
        url
      end
    end
end

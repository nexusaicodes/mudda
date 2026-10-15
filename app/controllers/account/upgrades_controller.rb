# Hands the signed-in owner to the platform's upgrade page (the account's upgrade_url), passing on the
# billing (monthly or yearly) they picked. The platform's "Go Premium" sends a returning
# customer here, so signing in to their board is how they show it's theirs; a signed-out
# visitor signs in first and comes back. With no upgrade URL there is nowhere to send them: the
# account either has no ceiling to lift, or has one this deployment offers no way past.
class Account::UpgradesController < ApplicationController
  BILLINGS = %w[ monthly yearly ].freeze

  def show
    if upgrade_url = Current.account.upgrade_url
      redirect_to with_billing(upgrade_url), allow_other_host: true
    elsif Current.account.card_limited?
      redirect_to root_path, notice: t(".unavailable")
    else
      redirect_to root_path, notice: t(".already_unlimited")
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

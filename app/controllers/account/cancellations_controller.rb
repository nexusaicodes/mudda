class Account::CancellationsController < ApplicationController
  def create
    Current.account.cancel
    redirect_to session_menu_path(script_name: nil), notice: "Account deleted"
  end
end

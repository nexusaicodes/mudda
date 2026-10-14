class My::LocalesController < ApplicationController
  def update
    Current.user.settings.update!(locale: params[:locale].presence)
    redirect_back_or_to user_path(Current.user)
  end
end

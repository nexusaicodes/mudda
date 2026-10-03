class My::UsersController < ApplicationController
  serves_json :show

  def show
    @user = Current.user
  end
end

class My::UsersController < ApplicationController
  def show
    @user = Current.user
  end
end

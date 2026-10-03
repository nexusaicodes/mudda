class UsersController < ApplicationController
  wrap_parameters :user, include: %i[ name avatar ]

  serves_json :show, :update

  before_action :set_user

  def show
  end

  def edit
  end

  def update
    if @user.update(user_params)
      respond_to do |format|
        format.html { redirect_to @user }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render_json_errors @user.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    def set_user
      @user = Current.user
    end

    def user_params
      params.expect(user: [ :name, :avatar ])
    end
end

class Users::AvatarsController < ApplicationController
  allow_unauthenticated_access only: :show
  serves_json :destroy

  before_action :set_user, only: :show
  before_action :set_account_user, only: :destroy

  def show
    if @user.avatar.attached?
      redirect_to rails_blob_path(@user.avatar_thumbnail, disposition: "inline")
    elsif stale? @user, cache_control: cache_control
      render_initials
    end
  end

  def destroy
    @user.avatar.destroy

    respond_to do |format|
      format.html { redirect_to @user }
      format.json { head :no_content }
    end
  end

  private
    # Unscoped: the unauthenticated show has no Current.account. What it renders — an avatar
    # or a monogram — is what the sign-in page already shows, so an enumerable id costs nothing.
    def set_user
      @user = User.find(params[:user_id])
    end

    # Removing an avatar is a write, so it reaches only the caller's own account.
    def set_account_user
      @user = Current.account.users.find(params[:user_id])
    end

    def cache_control
      if @user == Current.user
        {}
      else
        { max_age: 30.minutes, stale_while_revalidate: 1.week }
      end
    end

    def render_initials
      render formats: :svg
    end
end

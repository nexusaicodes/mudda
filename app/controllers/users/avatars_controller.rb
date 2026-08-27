class Users::AvatarsController < ApplicationController
  allow_unauthenticated_access only: :show

  before_action :set_user

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
    # Unscoped: the unauthenticated show has no Current.account, and the UUID is unguessable.
    def set_user
      @user = User.find(params[:user_id])
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

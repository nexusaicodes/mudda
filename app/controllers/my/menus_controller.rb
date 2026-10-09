class My::MenusController < ApplicationController
  def show
    @filters = Current.user.filters.all
    @boards = Current.user.boards.ordered_by_recent_activity

    fresh_when etag: [ @filters, @boards, Current.account.upgrade_url ]
  end
end

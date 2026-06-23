class My::MenusController < ApplicationController
  def show
    @filters = Current.user.filters.all
    @boards = Current.user.boards.ordered_by_recently_accessed
    @accounts = Current.identity.accounts.active

    fresh_when etag: [ @filters, @boards, @accounts ]
  end
end

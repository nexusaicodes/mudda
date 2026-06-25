class Boards::AccessesController < ApplicationController
  include BoardScoped

  def index
    set_page_and_extract_portion_from @board.account.users.active.alphabetically.includes(:identity)
  end

  private
    def accessed_user_ids
      @accessed_user_ids ||= @board.accesses.where(user_id: @page.records.map(&:id)).pluck(:user_id).to_set
    end

    helper_method :accessed_user_ids
end

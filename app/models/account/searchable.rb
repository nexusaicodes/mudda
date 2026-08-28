module Account::Searchable
  extend ActiveSupport::Concern

  included do
    before_destroy :clear_search_records
  end

  private
    def clear_search_records
      Search::Record.where(board: boards).destroy_all
    end
end

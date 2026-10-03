module SearchTestHelper
  extend ActiveSupport::Concern

  included do
    self.use_transactional_tests = false

    setup :setup_search_test
    teardown :teardown_search_test
  end

  def setup_search_test
    clear_search_records
    Account.find_by(name: "Search Test")&.destroy
    User.find_by(email_address: "test@example.com")&.destroy

    @account = Account.create!(name: "Search Test")
    Current.account = @account
    @user = User.create!(name: "Test User", email_address: "test@example.com", account: @account)
    Current.user = @user
    @board = Board.create!(name: "Test Board", account: @account, creator: @user)
  end

  def teardown_search_test
    clear_search_records
    Account.find_by(name: "Search Test")&.destroy
    User.find_by(email_address: "test@example.com")&.destroy
  end

  private
    def clear_search_records
      ActiveRecord::Base.connection.execute("DELETE FROM search_records")
      ActiveRecord::Base.connection.execute("DELETE FROM search_records_fts")
    end
end

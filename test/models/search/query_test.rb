require "test_helper"

class Search::QueryTest < ActiveSupport::TestCase
  test "sanitizing keeps accented and non-Latin letters" do
    assert_equal "señor", sanitized("señor")
    assert_equal "日本語", sanitized("日本語")
  end

  test "sanitizing replaces punctuation with spaces" do
    assert_equal "a b", sanitized("a-b")
  end

  private
    def sanitized(terms)
      query = Search::Query.new(terms: terms)
      query.validate
      query.terms
    end
end

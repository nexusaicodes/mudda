require "test_helper"

class Search::QueryTest < ActiveSupport::TestCase
  test "sanitizing keeps accented and non-Latin letters" do
    assert_equal "señor", sanitized("señor")
    assert_equal "日本語", sanitized("日本語")
  end

  test "sanitizing replaces punctuation with spaces" do
    assert_equal "a b", sanitized("a-b")
  end

  test "the match expression quotes every word and phrase" do
    assert_equal %("ship" "OR" "not"), expression("ship OR not")
    assert_equal %("a b" "NEAR"), expression(%("a b" NEAR))
    assert_equal %("NOT"), expression("NOT")
  end

  test "terms that leave nothing to match are invalid" do
    assert_not Search::Query.new(terms: %("")).valid?
    assert_not Search::Query.new(terms: "(*)").valid?
  end

  private
    def expression(terms)
      Search::Query.new(terms: terms).tap(&:validate).match_expression
    end

    def sanitized(terms)
      query = Search::Query.new(terms: terms)
      query.validate
      query.terms
    end
end

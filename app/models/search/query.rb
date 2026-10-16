# What a person typed into search, cleaned up for FTS5: stray punctuation and unbalanced quotes
# removed, and folded the way the index is (Search::Normalizer). It reaches FTS5 as
# match_expression, where every word and phrase is quoted, so nothing typed is read as syntax.
class Search::Query
  # FTS5 refused the expression; a 422, since it is what was typed that can't be searched for.
  class Invalid < StandardError; end

  include ActiveModel::Model
  include ActiveModel::Validations::Callbacks

  attr_accessor :terms

  validates :terms, :match_expression, presence: true
  before_validation :sanitize_terms

  delegate :to_s, to: :terms

  # FTS5 operators (OR, AND, NOT, NEAR) are only operators when bare, so quoting each word and
  # each quoted phrase searches for them as the words they are.
  def match_expression
    terms.to_s.scan(/"([^"]*)"|([^\s"]+)/).filter_map { |phrase, word| (phrase || word).squish.presence }
      .map { |term| %("#{term}") }.join(" ")
  end

  class << self
    def wrap(query)
      if query.is_a?(self)
        query
      else
        self.new(terms: query)
      end
    end
  end

  private
    def sanitize_terms
      self.terms = sanitize(terms)
    end

    def sanitize(terms)
      if terms.present?
        terms = remove_invalid_search_characters(self.terms)
        terms = Search::Normalizer.normalize(terms)
        terms = remove_unbalanced_quotes(terms)
        terms.presence
      else
        terms
      end
    end

    def remove_invalid_search_characters(terms)
      terms.gsub(/[^\p{Word}"]/, " ")
    end

    def remove_unbalanced_quotes(terms)
      if terms.count("\"").even?
        terms
      else
        terms.gsub("\"", " ")
      end
    end
end

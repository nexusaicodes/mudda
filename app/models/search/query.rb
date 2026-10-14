# What a person typed into search, cleaned up for FTS5: stray punctuation and unbalanced quotes
# removed, and folded the way the index is (Search::Normalizer).
class Search::Query
  include ActiveModel::Model
  include ActiveModel::Validations::Callbacks

  attr_accessor :terms

  validates :terms, presence: true
  before_validation :sanitize_terms

  delegate :to_s, to: :terms

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

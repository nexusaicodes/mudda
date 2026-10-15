# Marks the words of a text that a query matched. The query holds terms already normalized
# by Search::Query; words of the text are normalized before comparing, so an Arabic word is marked as written, vowels and article included. The text is
# HTML-escaped and only the marks are left as markup.
class Search::Highlighter
  OPENING_MARK = "<mark class=\"circled-text\"><span></span>"
  CLOSING_MARK = "</mark>"
  ELIPSIS = "..."
  WORD = /\p{Word}+/

  attr_reader :query

  def initialize(query)
    @query = query.to_s
  end

  def highlight(text)
    words = text.to_enum(:scan, WORD).map { Regexp.last_match }
    ranges = matched_ranges(words)
    result = +""
    position = 0

    ranges.each do |range|
      result << CGI.escapeHTML(text[position...range.begin])
      result << OPENING_MARK << CGI.escapeHTML(text[range]) << CLOSING_MARK
      position = range.end
    end

    (result << CGI.escapeHTML(text[position..].to_s)).html_safe
  end

  def snippet(text, max_words: 20)
    words = text.split(/\s+/)
    match_index = words.index { |word| word.scan(WORD).any? { |part| term_words.flatten.any? { |term| matches?(part, term) } } }

    if words.length <= max_words
      highlight(text)
    elsif match_index
      start_index = [ 0, match_index - max_words / 2 ].max
      end_index = [ words.length - 1, start_index + max_words - 1 ].min

      snippet_text = words[start_index..end_index].join(" ")
      snippet_text = "#{ELIPSIS}#{snippet_text}" if start_index > 0
      snippet_text = "#{snippet_text}#{ELIPSIS}" if end_index < words.length - 1

      highlight(snippet_text)
    else
      CGI.escapeHTML(text.truncate_words(max_words, omission: ELIPSIS)).html_safe
    end
  end

  private
    # The character ranges covered by each run of words matching a whole term.
    def matched_ranges(words)
      ranges = []
      index = 0

      while index < words.length
        if length = term_words.filter_map { |term| term.length if run_matches?(words, index, term) }.max
          ranges << (words[index].begin(0)...words[index + length - 1].end(0))
          index += length
        else
          index += 1
        end
      end

      ranges
    end

    def run_matches?(words, index, term)
      term.each_with_index.all? { |term_word, offset| words[index + offset] && matches?(words[index + offset][0], term_word) }
    end

    def matches?(word, term_word)
      normalize(word).start_with?(term_word)
    end

    # Each term as its words: a quoted phrase is one term of several words.
    def term_words
      @term_words ||= begin
        phrases = query.scan(/"([^"]+)"/).map(&:first)
        words = query.gsub(/"[^"]+"/, " ").split(/\s+/)

        (phrases + words).map { |term| term.downcase.scan(WORD) }.reject(&:empty?).uniq
      end
    end

    def normalize(text)
      Search::Normalizer.normalize(text).downcase
    end
end

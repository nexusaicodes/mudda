# Folds Arabic text to the form the full-text index matches on, so a query finds a word
# however it is vowelled, spelled with hamza, or prefixed with the definite article. Text
# with no Arabic letters is returned untouched, leaving English to the porter stemmer.
module Search::Normalizer
  ARABIC = /\p{Arabic}/
  HARAKAT_AND_TATWEEL = /[\u064B-\u065F\u0670\u0640]/
  LETTER_FOLDS = { "أ" => "ا", "إ" => "ا", "آ" => "ا", "ٱ" => "ا", "ى" => "ي", "ة" => "ه" }
  LETTERS_TO_FOLD = /[#{LETTER_FOLDS.keys.join}]/
  ARTICLE = /\A(?:وال|بال|كال|فال|ال)(?=\p{Arabic}{2})/
  LAM_ARTICLE = /\Aلل(?=\p{Arabic})/

  extend self

  def normalize(text)
    if text.is_a?(String) && text.match?(ARABIC)
      text.gsub(HARAKAT_AND_TATWEEL, "").gsub(LETTERS_TO_FOLD, LETTER_FOLDS).gsub(/\p{Arabic}+/) { |word| strip_article(word) }
    else
      text
    end
  end

  private
    def strip_article(word)
      if word.match?(ARTICLE)
        word.sub(ARTICLE, "")
      elsif word.match?(LAM_ARTICLE) && word.length >= 3
        word.sub(LAM_ARTICLE, "ل")
      else
        word
      end
    end
end

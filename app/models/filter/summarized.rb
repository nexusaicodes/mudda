module Filter::Summarized
  def summary
    [ index_summary, sort_summary, terms_summary ].compact.to_sentence
  end

  private
    def index_summary
      unless indexed_by.all?
        indexed_by.humanize
      end
    end

    def sort_summary
      unless sorted_by.latest?
        sorted_by.humanize
      end
    end

    def terms_summary
      if terms.any?
        "matching #{terms.map { |term| %Q("#{term}") }.to_sentence}"
      end
    end
end

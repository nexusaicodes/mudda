class Filter < ApplicationRecord
  include Fields, Params, Resources, Summarized

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { creator.account }

  class << self
    def from_params(params)
      find_by_params(params) || build(params)
    end

    def remember(attrs)
      create!(attrs)
    rescue ActiveRecord::RecordNotUnique
      find_by_params(attrs).tap(&:touch)
    end
  end

  def cards
    @cards ||= begin
      result = creator.accessible_cards.preloaded.published
      result = result.indexed_by(indexed_by)
      result = result.sorted_by(sorted_by)
      result = result.where(id: card_ids) if card_ids.present?
      result = result.unassigned if assignment_status.unassigned?
      result = result.assigned_to(assignees.ids) if assignees.present?
      result = result.where(creator_id: creators.ids) if creators.present?
      result = result.where(board: boards.ids) if boards.present?
      result = result.where(cards: { created_at: creation_window }) if creation_window
      result = terms.reduce(result) do |result, term|
        result.mentioning(term, user: creator)
      end
      result = result.where(column_id: column_ids) if column_ids.present?

      result.distinct
    end
  end

  def empty?
    self.class.normalize_params(as_params).blank?
  end

  def single_board
    boards.first if boards.one?
  end

  def single_workflow
    boards.first.workflow if boards.pluck(:workflow_id).uniq.one?
  end

  def cacheable?
    boards.exists?
  end

  def cache_key
    ActiveSupport::Cache.expand_cache_key params_digest, "filter"
  end
end

# Repair task — reindexes every searchable Card and Note in the database.
# Intended to be invoked manually after a search-index loss event. Not a recurring job.
#
# Idempotent: Searchable#reindex upserts by (searchable_type, searchable_id).
# Continuable: if the worker is interrupted, the job resumes from the last-processed id.
#
# `rich_text_limit` is a safety valve against unbounded bodies: records whose rich text
# exceeds the limit (in bytes) are filtered out at the SQL level, so they never materialize
# in Ruby. Without it, a single pathological body can stall the batch query or OOM the
# worker during preload, which has happened in practice. Those records are counted as skipped.
#
# A record that fails to reindex is reported and counted as failed, and the run carries on.
# `stats` holds the counts, and the run ends with one search.reindex.completed line: at warn
# when anything was skipped or failed, so a partial reindex doesn't pass as a whole one.
#
# Usage:
#   SearchReindexJob.perform_later
#   SearchReindexJob.perform_later(batch_size: 500, log_every: 100, rich_text_limit: 50_000)
class SearchReindexJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :backend

  BODY_SIZE = "action_text_rich_texts.body IS NULL OR OCTET_LENGTH(action_text_rich_texts.body) <= ?"

  def stats
    @stats ||= Hash.new(0)
  end

  def perform(batch_size: 100, log_every: 1000, rich_text_limit: 100_000)
    step :cards do |step|
      cards = Card.left_joins(:rich_text_description)
      count_skipped :cards, cards.where.not(BODY_SIZE, rich_text_limit) if step.cursor.nil?

      cards.where(BODY_SIZE, rich_text_limit).includes(:rich_text_description)
          .find_each(start: step.cursor, batch_size: batch_size) do |card|
        safely_reindex(card, log_every)
        step.advance! from: card.id
      end
    end

    step :notes do |step|
      notes = Note.left_joins(:rich_text_body)
      count_skipped :notes, notes.where.not(BODY_SIZE, rich_text_limit) if step.cursor.nil?

      notes.where(BODY_SIZE, rich_text_limit).includes(:rich_text_body, :card)
          .find_each(start: step.cursor, batch_size: batch_size) do |note|
        safely_reindex(note, log_every)
        step.advance! from: note.id
      end
    end

    log_completion
  end

  private
    def count_skipped(kind, oversized)
      if (count = oversized.count).positive?
        stats[:skipped] += count
        StructuredLog.warn("search.reindex.skipped", kind: kind, count: count, reason: "rich text over the limit")
      end
    end

    def safely_reindex(record, log_every)
      record.reindex
      stats[:indexed] += 1
      StructuredLog.info("search.reindex.progress", record_type: record.class.name, indexed: stats[:indexed], cursor: record.id) if (stats[:indexed] % log_every).zero?
    rescue StandardError => error
      stats[:failed] += 1
      Rails.error.report error, handled: true, severity: :error, source: "mudda.search_reindex",
        context: { record_type: record.class.name, record_id: record.id }
    end

    def log_completion
      level = stats[:skipped].positive? || stats[:failed].positive? ? :warn : :info
      StructuredLog.public_send(level, "search.reindex.completed", indexed: stats[:indexed], skipped: stats[:skipped], failed: stats[:failed])
    end
end

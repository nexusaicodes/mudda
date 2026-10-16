# The board's state as Prometheus text exposition (format 0.0.4), served by MetricsController.
# Every series is an instance-wide total; labels are drawn from small fixed sets, never from
# per-board or per-user values.
class Metrics::Exposition
  CONTENT_TYPE = "text/plain; version=0.0.4; charset=utf-8"
  PREFIX = "mudda_board_"

  def initialize(now: Time.current, database_path: Metrics::Exposition.database_path, version: ENV["GIT_SHA"])
    @now, @database_path, @version = now, database_path, version.presence || "unknown"
    @lines = []
  end

  def self.database_path
    ActiveRecord::Base.connection_db_config.database
  end

  def render
    counts
    webhook_deliveries
    database_files
    gauge "build_info", "Build of the running app; the value is always 1.", { version: @version } => 1
    @lines.join("\n") << "\n"
  end

  private
    def counts
      gauge "accounts", "Accounts.", nil => Account.count
      gauge "users", "Users.", nil => User.count
      gauge "boards", "Boards.", nil => Board.count
      gauge "cards", "Cards by the lane (column name) they are in.",
        Card.joins(:column).group("columns.name").count.sort.to_h { |name, count| [ { column: name }, count ] }
      gauge "notes", "Notes on cards.", nil => Note.count
    end

    # pending: due to be sent now. scheduled: waiting for a retry, or claimed by a sender until its
    # lease runs out. abandoned: given up on. delivered: sent.
    def webhook_deliveries
      undelivered = WebhookDelivery.where(delivered_at: nil)
      states = {
        "pending" => undelivered.where(next_attempt_at: ..@now).count,
        "scheduled" => undelivered.where("next_attempt_at > ?", @now).count,
        "abandoned" => undelivered.where(next_attempt_at: nil).count,
        "delivered" => WebhookDelivery.where.not(delivered_at: nil).count
      }
      gauge "webhook_deliveries", "Webhook deliveries by state.", states.to_h { |state, count| [ { state: state }, count ] }

      oldest = WebhookDelivery.pending.minimum(:created_at)
      gauge "webhook_delivery_oldest_pending_age_seconds",
        "Age of the oldest undelivered, not abandoned webhook delivery; 0 when there is none.",
        nil => oldest ? (@now - oldest).round(3).clamp(0..) : 0
    end

    def database_files
      return unless @database_path

      gauge "database_size_bytes", "Size of the primary SQLite database file.", nil => file_size(@database_path)
      gauge "wal_size_bytes", "Size of the primary SQLite database's write-ahead log; 0 when absent.", nil => file_size("#{@database_path}-wal")
    end

    def file_size(path)
      File.size?(path) || 0
    end

    def gauge(name, help, samples)
      @lines << "# HELP #{PREFIX}#{name} #{help}" << "# TYPE #{PREFIX}#{name} gauge"
      samples.each { |labels, value| @lines << "#{PREFIX}#{name}#{format_labels(labels)} #{value}" }
    end

    def format_labels(labels)
      return "" if labels.blank?
      "{" + labels.map { |key, value| %(#{key}="#{escape(value)}") }.join(",") + "}"
    end

    def escape(value)
      value.to_s.gsub(/[\\"\n]/, "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n")
    end
end

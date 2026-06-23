# frozen_string_literal: true

# Adds a date arithmetic helper to the SQLite adapter so query code can subtract
# seconds from a column without inlining adapter-specific SQL.
#
# Usage:
#   connection.date_subtract("created_at", "3600")
#   # => "datetime(created_at, '-' || (3600) || ' seconds')"

module SqliteDateArithmetic
  # Generates SQL for subtracting seconds from a date/time column in SQLite.
  #
  # @param date_column [String] The date/time column or expression
  # @param seconds_expression [String] SQL expression that evaluates to number of seconds
  # @return [String] SQLite datetime expression
  #
  # Example:
  #   date_subtract("last_active_at", "COALESCE(auto_postpone_period, 3600)")
  #   # => "datetime(last_active_at, '-' || (COALESCE(auto_postpone_period, 3600)) || ' seconds')"
  def date_subtract(date_column, seconds_expression)
    "datetime(#{date_column}, '-' || (#{seconds_expression}) || ' seconds')"
  end
end

ActiveSupport.on_load(:active_record) do
  if defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
    ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(SqliteDateArithmetic)
  end
end

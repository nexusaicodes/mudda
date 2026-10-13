Color = Struct.new(:key, :value)

class Color
  class << self
    # Finds a Color by its CSS value (e.g. "var(--color-card-4)").
    # Falls back to extracting the value from legacy export formats where
    # the Color struct was serialized instead of the raw CSS string.
    def for_value(value)
      COLORS.find { |it| it.value == value } ||
        extract_from_legacy_export(value)
    end

    private
      # Broken exports serialized Color structs instead of raw CSS values,
      # producing JSON like {"name":"Emerald","value":"var(--color-card-4)"}.
      # Parse it and extract the value.
      def extract_from_legacy_export(value)
        parsed = value.is_a?(String) && JSON.parse(value)
        COLORS.find { |it| it.value == parsed["value"] } if parsed.is_a?(Hash)
      rescue JSON::ParserError
      end
  end

  def name
    I18n.t("colors.#{key}")
  end

  def to_s
    value
  end

  COLORS = {
    blue: "var(--color-card-default)",
    periwinkle: "var(--color-card-1)",
    indigo: "var(--color-card-2)",
    azure: "var(--color-card-3)",
    emerald: "var(--color-card-4)",
    amber: "var(--color-card-5)",
    violet: "var(--color-card-6)",
    purple: "var(--color-card-7)",
    pink: "var(--color-card-8)"
  }.collect { |key, value| new(key, value) }.freeze
end

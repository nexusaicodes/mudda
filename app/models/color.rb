Color = Struct.new(:key, :value)

class Color
  class << self
    # Finds a Color by its CSS value (e.g. "var(--color-card-4)").
    def for_value(value)
      COLORS.find { |it| it.value == value }
    end
  end

  def name
    I18n.t("colors.#{key}")
  end

  def to_s
    value
  end

  # The API always speaks English, whatever the request locale.
  def as_json(*)
    { "name" => I18n.t("colors.#{key}", locale: :en), "value" => value }
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

module Aver
  VALID_TELEMETRY_MODES = %w[warn fail off].freeze

  def self.resolve_telemetry_mode(override: nil)
    if override
      unless VALID_TELEMETRY_MODES.include?(override)
        raise ArgumentError, "Invalid telemetry mode '#{override}'. Valid values: #{VALID_TELEMETRY_MODES.sort.join(', ')}"
      end
      return override
    end

    env_mode = ENV["AVER_TELEMETRY_MODE"]
    if env_mode
      unless VALID_TELEMETRY_MODES.include?(env_mode)
        raise ArgumentError, "Invalid AVER_TELEMETRY_MODE '#{env_mode}'. Valid values: #{VALID_TELEMETRY_MODES.sort.join(', ')}"
      end
      return env_mode
    end

    # Default: fail on CI, warn locally
    ENV["CI"] ? "fail" : "warn"
  end
end

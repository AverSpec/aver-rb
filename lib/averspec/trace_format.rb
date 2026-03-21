require "json"

module Aver
  def self.format_trace(entries)
    lines = []

    entries.each do |entry|
      icon = entry.status == "pass" ? "[PASS]" : "[FAIL]"
      label = _category_label(entry)

      payload_str = ""
      raw = _serialize_payload(entry.payload)
      if raw
        if entry.status == "fail" || raw.length <= 60
          payload_str = raw
        else
          payload_str = "#{raw[0, 57]}..."
        end
      end

      duration_str = ""
      if entry.duration_ms && entry.duration_ms > 0
        ms = entry.duration_ms
        if ms == ms.to_i
          duration_str = "  #{ms.to_i}ms"
        else
          duration_str = "  #{ms.round(1)}ms"
        end
      end

      error_str = ""
      if entry.status == "fail" && entry.error
        error_str = " -- #{entry.error}"
      end

      line = "  #{icon} #{label} #{entry.name}(#{payload_str})#{duration_str}#{error_str}"
      lines << line

      # Telemetry info
      if entry.telemetry.is_a?(TelemetryMatchResult)
        telem = entry.telemetry
        if telem.matched && telem.matched_span
          attrs_str = ""
          if telem.expected.attributes && !telem.expected.attributes.empty?
            attrs_str = " #{JSON.generate(telem.expected.attributes)}"
          end
          lines << "         \u2713 telemetry: #{telem.expected.span}#{attrs_str}"
        else
          lines << "         \u26a0 telemetry: expected span '#{telem.expected.span}' not found"
        end
      end
    end

    lines.join("\n")
  end

  private

  def self._category_label(entry)
    if entry.category && !entry.category.empty?
      return entry.category.upcase.ljust(6)
    end
    mapping = {
      "action" => "ACT   ",
      "query" => "QUERY ",
      "assertion" => "ASSERT",
    }
    mapping.fetch(entry.kind, entry.kind.upcase.ljust(6))
  end

  def self._serialize_payload(payload)
    return nil if payload.nil?
    begin
      JSON.generate(payload)
    rescue
      "[unserializable]"
    end
  end
end

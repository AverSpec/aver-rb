module Aver
  class CorrelationGroup
    attr_accessor :key, :value, :steps

    def initialize(key:, value:, steps: [])
      @key = key
      @value = value
      @steps = steps
    end
  end

  class CorrelationViolation
    attr_accessor :kind, :key, :value, :steps, :message

    def initialize(kind:, key:, value: "", steps: [], message: "")
      @kind = kind
      @key = key
      @value = value
      @steps = steps
      @message = message
    end
  end

  class CorrelationResult
    attr_accessor :groups, :violations

    def initialize(groups: [], violations: [])
      @groups = groups
      @violations = violations
    end
  end

  def self.verify_correlation(trace)
    steps_with_telemetry = []
    trace.each_with_index do |entry, i|
      next unless entry.telemetry.is_a?(TelemetryMatchResult)
      next unless entry.telemetry.expected.attributes && !entry.telemetry.expected.attributes.empty?
      next unless entry.telemetry.matched

      steps_with_telemetry << {
        name: entry.name,
        index: i,
        expected: entry.telemetry.expected.attributes,
        causes: entry.telemetry.expected.causes || [],
        matched_span: entry.telemetry.matched_span,
      }
    end

    # Group by shared (attribute key, expected value)
    key_value_map = {}
    steps_with_telemetry.each do |step|
      step[:expected].each do |key, value|
        composite_key = "#{key}=#{value}"
        key_value_map[composite_key] ||= []
        key_value_map[composite_key] << step
      end
    end

    groups = []
    violations = []

    key_value_map.each do |composite_key, steps|
      next if steps.length < 2

      eq_idx = composite_key.index("=")
      key = composite_key[0...eq_idx]
      value = composite_key[(eq_idx + 1)..]

      groups << CorrelationGroup.new(
        key: key,
        value: value,
        steps: steps.map { |s| { name: s[:name], index: s[:index] } }
      )

      step_names = steps.map { |s| s[:name] }

      # Attribute correlation
      steps.each do |step|
        matched_span = step[:matched_span]
        if matched_span.nil?
          violations << CorrelationViolation.new(
            kind: "attribute-mismatch",
            key: key,
            value: value,
            steps: step_names,
            message: "Expected attribute '#{key}' on span for step '#{step[:name]}' but span was not matched"
          )
          next
        end

        actual = matched_span.attributes[key]
        if actual.nil?
          violations << CorrelationViolation.new(
            kind: "attribute-mismatch",
            key: key,
            value: value,
            steps: step_names,
            message: "Expected attribute '#{key}' on span '#{matched_span.name}' for step '#{step[:name]}' but not found"
          )
        elsif actual.to_s != value
          violations << CorrelationViolation.new(
            kind: "attribute-mismatch",
            key: key,
            value: value,
            steps: step_names,
            message: "Expected attribute '#{key}' = '#{value}' on span '#{matched_span.name}' for step '#{step[:name]}' but got '#{actual}'"
          )
        end
      end

      # Causal correlation
      steps.each do |step|
        causes = step[:causes] || []
        next if causes.empty?

        matched_span = step[:matched_span]
        next if matched_span.nil? || matched_span.trace_id.nil? || matched_span.trace_id.empty?

        causes.each do |target_span_name|
          target = steps.find { |s| s[:matched_span]&.name == target_span_name }
          next if target.nil? || target[:matched_span].nil?
          next if target[:matched_span].trace_id.nil? || target[:matched_span].trace_id.empty?

          # Same trace = causally connected
          next if matched_span.trace_id == target[:matched_span].trace_id

          # Different trace: check for span links
          linked = false
          (target[:matched_span].links || []).each do |link|
            if link.span_id == matched_span.span_id
              linked = true
              break
            end
          end

          unless linked
            (matched_span.links || []).each do |link|
              if link.span_id == target[:matched_span].span_id
                linked = true
                break
              end
            end
          end

          unless linked
            violations << CorrelationViolation.new(
              kind: "causal-break",
              key: key,
              value: value,
              steps: [step[:name], target_span_name],
              message: "'#{matched_span.name}' declares causes: ['#{target_span_name}'] but spans are in different traces (#{matched_span.trace_id}, #{target[:matched_span].trace_id}) with no link. Propagate trace context or add a span link at the async boundary."
            )
          end
        end
      end
    end

    CorrelationResult.new(groups: groups, violations: violations)
  end
end

module Aver
  class ProductionSpan
    attr_accessor :name, :attributes, :span_id, :parent_span_id

    def initialize(name:, attributes: {}, span_id: nil, parent_span_id: nil)
      @name = name
      @attributes = attributes
      @span_id = span_id
      @parent_span_id = parent_span_id
    end
  end

  class ProductionTrace
    attr_accessor :trace_id, :spans

    def initialize(trace_id:, spans: [])
      @trace_id = trace_id
      @spans = spans
    end
  end

  class Violation
    attr_accessor :kind, :span_name, :trace_id, :span, :attribute, :expected, :actual, :symbol, :paths, :anchor_span, :message

    def initialize(kind:, span_name: nil, trace_id: nil, span: nil, attribute: nil, expected: nil, actual: nil, symbol: nil, paths: nil, anchor_span: nil, message: nil)
      @kind = kind
      @span_name = span_name
      @trace_id = trace_id
      @span = span
      @attribute = attribute
      @expected = expected
      @actual = actual
      @symbol = symbol
      @paths = paths
      @anchor_span = anchor_span
      @message = message
    end
  end

  class EntryVerificationResult
    attr_accessor :test_name, :traces_matched, :traces_checked, :violations

    def initialize(test_name:, traces_matched:, traces_checked:, violations: [])
      @test_name = test_name
      @traces_matched = traces_matched
      @traces_checked = traces_checked
      @violations = violations
    end
  end

  class ConformanceReport
    attr_accessor :domain, :results, :total_violations

    def initialize(domain:, results: [], total_violations: 0)
      @domain = domain
      @results = results
      @total_violations = total_violations
    end
  end

  def self.verify_contract(contract, traces)
    results = contract.entries.map do |entry|
      _verify_entry(entry, traces)
    end

    total = results.sum { |r| r.violations.length }

    ConformanceReport.new(
      domain: contract.domain,
      results: results,
      total_violations: total
    )
  end

  private

  def self._find_matching_span(expected_span, trace, used_span_ids)
    span_id_to_name = {}
    trace.spans.each do |s|
      span_id_to_name[s.span_id] = s.name if s.span_id
    end

    trace.spans.each do |s|
      next unless s.name == expected_span.name
      next if s.span_id && used_span_ids.include?(s.span_id)

      if expected_span.parent_name
        next unless s.parent_span_id
        actual_parent = span_id_to_name[s.parent_span_id]
        next unless actual_parent == expected_span.parent_name
      end

      return s
    end

    nil
  end

  def self._verify_entry(entry, traces)
    if entry.spans.empty?
      return EntryVerificationResult.new(
        test_name: entry.test_name,
        traces_matched: 0,
        traces_checked: 0
      )
    end

    anchor_name = entry.spans[0].name
    matching_traces = traces.select do |t|
      t.spans.any? { |s| s.name == anchor_name }
    end

    violations = []

    if matching_traces.empty?
      violations << Violation.new(
        kind: "no-matching-traces",
        anchor_span: anchor_name,
        message: "Contract entry '#{entry.test_name}' matched zero production traces -- anchor span '#{anchor_name}' not found in any trace."
      )
    end

    matching_traces.each do |trace|
      used_span_ids = Set.new
      matched_spans = {}

      entry.spans.each_with_index do |expected_span, i|
        prod_span = _find_matching_span(expected_span, trace, used_span_ids)

        if prod_span.nil?
          violations << Violation.new(
            kind: "missing-span",
            span_name: expected_span.name,
            trace_id: trace.trace_id
          )
          next
        end

        used_span_ids.add(prod_span.span_id) if prod_span.span_id
        matched_spans[i] = prod_span

        # Check literal attributes
        expected_span.attributes.each do |attr_key, binding|
          if binding.kind == "literal"
            actual = prod_span.attributes[attr_key]
            if actual != binding.value
              violations << Violation.new(
                kind: "literal-mismatch",
                span: expected_span.name,
                attribute: attr_key,
                expected: binding.value,
                actual: actual,
                trace_id: trace.trace_id
              )
            end
          end
        end
      end

      # Check correlations
      symbol_values = {}
      entry.spans.each_with_index do |expected_span, i|
        prod_span = matched_spans[i]
        next unless prod_span

        expected_span.attributes.each do |attr_key, binding|
          if binding.kind == "correlated" && binding.symbol
            value = prod_span.attributes[attr_key]
            symbol_values[binding.symbol] ||= []
            symbol_values[binding.symbol] << {
              span: expected_span.name,
              attribute: attr_key,
              value: value
            }
          end
        end
      end

      symbol_values.each do |symbol, paths|
        next if paths.length < 2
        first_value = paths[0][:value]
        unless paths.all? { |p| p[:value] == first_value }
          violations << Violation.new(
            kind: "correlation-violation",
            symbol: symbol,
            paths: paths,
            trace_id: trace.trace_id
          )
        end
      end
    end

    EntryVerificationResult.new(
      test_name: entry.test_name,
      traces_matched: matching_traces.length,
      traces_checked: traces.length,
      violations: violations
    )
  end
end

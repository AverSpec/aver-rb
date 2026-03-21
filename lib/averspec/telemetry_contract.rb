module Aver
  class AttributeBinding
    attr_accessor :kind, :value, :symbol

    def initialize(kind:, value: nil, symbol: nil)
      @kind = kind
      @value = value
      @symbol = symbol
    end
  end

  class SpanExpectation
    attr_accessor :name, :attributes, :parent_name

    def initialize(name:, attributes: {}, parent_name: nil)
      @name = name
      @attributes = attributes
      @parent_name = parent_name
    end
  end

  class ContractEntry
    attr_accessor :test_name, :spans

    def initialize(test_name:, spans: [])
      @test_name = test_name
      @spans = spans
    end
  end

  class BehavioralContract
    attr_accessor :domain, :entries

    def initialize(domain:, entries: [])
      @domain = domain
      @entries = entries
    end
  end

  def self.extract_contract(domain, results)
    entries = []

    results.each do |result|
      spans = _extract_spans(domain, result[:trace])
      if spans.any?
        entries << ContractEntry.new(
          test_name: result[:test_name],
          spans: spans
        )
      end
    end

    BehavioralContract.new(domain: domain.name, entries: entries)
  end

  private

  def self._extract_spans(domain, trace)
    spans = []

    # Build span_id -> name map for parent lookups
    span_id_to_name = {}
    trace.each do |entry|
      if entry.telemetry.is_a?(TelemetryMatchResult) && entry.telemetry.matched_span
        ms = entry.telemetry.matched_span
        span_id_to_name[ms.span_id] = ms.name if ms.span_id && !ms.span_id.empty?
      end
    end

    trace.each do |entry|
      next unless entry.telemetry.is_a?(TelemetryMatchResult)
      next unless entry.telemetry.expected

      expected = entry.telemetry.expected
      attributes = {}

      # All literal for Ruby port (no callable telemetry introspection)
      expected.attributes.each do |attr_key, attr_value|
        attributes[attr_key] = AttributeBinding.new(kind: "literal", value: attr_value)
      end

      # Resolve parent name
      parent_name = nil
      matched_span = entry.telemetry.matched_span
      if matched_span&.parent_span_id && !matched_span.parent_span_id.empty?
        parent_name = span_id_to_name[matched_span.parent_span_id]
      end

      spans << SpanExpectation.new(
        name: expected.span,
        attributes: attributes,
        parent_name: parent_name
      )
    end

    spans
  end
end

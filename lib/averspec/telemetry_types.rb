module Aver
  class SpanLink
    attr_accessor :trace_id, :span_id

    def initialize(trace_id:, span_id:)
      @trace_id = trace_id
      @span_id = span_id
    end
  end

  class CollectedSpan
    attr_accessor :trace_id, :span_id, :name, :attributes, :parent_span_id, :links

    def initialize(trace_id:, span_id:, name:, attributes: {}, parent_span_id: nil, links: [])
      @trace_id = trace_id
      @span_id = span_id
      @name = name
      @attributes = attributes
      @parent_span_id = parent_span_id
      @links = links
    end
  end

  class TelemetryExpectation
    attr_accessor :span, :attributes, :causes

    def initialize(span:, attributes: {}, causes: [])
      @span = span
      @attributes = attributes
      @causes = causes
    end
  end

  class TelemetryMatchResult
    attr_accessor :expected, :matched, :matched_span

    def initialize(expected:, matched:, matched_span: nil)
      @expected = expected
      @matched = matched
      @matched_span = matched_span
    end
  end
end

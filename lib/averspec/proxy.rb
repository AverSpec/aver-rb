module Aver
  class NarrativeProxy
    ALLOWED = {
      given: [:action, :assertion],
      when: [:action],
      then: [:assertion],
      query: [:query],
    }.freeze

    def initialize(domain:, adapter:, protocol_ctx:, trace:, category:, called_markers: nil, protocol: nil)
      @domain = domain
      @adapter = adapter
      @ctx = protocol_ctx
      @trace = trace
      @category = category
      @allowed_kinds = ALLOWED[category]
      @called_markers = called_markers
      @protocol = protocol
    end

    def method_missing(name, *args, **kwargs, &block)
      domain_markers = _get_markers
      domain_name = _get_domain_name
      marker = domain_markers[name]
      raise NoMethodError, "Domain '#{domain_name}' has no marker '#{name}'" unless marker

      unless @allowed_kinds.include?(marker.kind)
        raise TypeError, "ctx.#{@category}.#{name} — '#{name}' is a #{marker.kind}, but ctx.#{@category} only accepts #{@allowed_kinds.join(', ')}"
      end

      payload = kwargs.empty? ? args.first : kwargs
      @called_markers&.add(name)

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        result = @adapter.execute(name, @ctx, payload)
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
        entry = TraceEntry.new(
          kind: marker.kind.to_s, category: @category.to_s,
          name: "#{domain_name}.#{name}", payload: payload,
          status: "pass", duration_ms: elapsed, result: result
        )
        _apply_telemetry_verification(entry, payload, marker)
        @trace << entry
        result
      rescue => e
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
        entry = TraceEntry.new(
          kind: marker.kind.to_s, category: @category.to_s,
          name: "#{domain_name}.#{name}", payload: payload,
          status: "fail", duration_ms: elapsed, error: e.message
        )
        @trace << entry
        raise
      end
    end

    def respond_to_missing?(name, include_private = false)
      _get_markers.key?(name) || super
    end

    private

    def _get_markers
      @domain.respond_to?(:markers) ? @domain.markers : {}
    end

    def _get_domain_name
      @domain.respond_to?(:domain_name) ? @domain.domain_name : (@domain.respond_to?(:name) ? @domain.name : "unknown")
    end

    def _apply_telemetry_verification(entry, payload, marker)
      return unless marker.telemetry
      return unless @protocol
      collector = @protocol.telemetry
      return unless collector

      mode = Aver.resolve_telemetry_mode
      return if mode == "off"

      expectation = if marker.telemetry.respond_to?(:call)
        marker.telemetry.call(payload)
      else
        marker.telemetry
      end

      spans = collector.get_spans
      matched_span = spans.find { |s| _match_span(s, expectation) }

      if matched_span
        entry.telemetry = TelemetryMatchResult.new(
          expected: expectation, matched: true, matched_span: matched_span
        )
      else
        entry.telemetry = TelemetryMatchResult.new(
          expected: expectation, matched: false
        )
        if mode == "fail"
          entry.status = "fail"
          raise "Telemetry verification failed: expected span '#{expectation.span}' not found"
        end
      end
    end

    def _match_span(span, expectation)
      return false unless span.name == expectation.span
      (expectation.attributes || {}).each do |key, value|
        return false unless span.attributes[key] == value
      end
      true
    end
  end
end

module Aver
  class NarrativeProxy
    ALLOWED = {
      given: [:action, :assertion],
      when: [:action],
      then: [:assertion],
      query: [:query],
    }.freeze

    def initialize(domain:, adapter:, protocol_ctx:, trace:, category:, called_markers: nil)
      @domain = domain
      @adapter = adapter
      @ctx = protocol_ctx
      @trace = trace
      @category = category
      @allowed_kinds = ALLOWED[category]
      @called_markers = called_markers
    end

    def method_missing(name, *args, **kwargs, &block)
      marker = @domain.markers[name]
      raise NoMethodError, "Domain '#{@domain.name}' has no marker '#{name}'" unless marker

      unless @allowed_kinds.include?(marker.kind)
        raise TypeError, "ctx.#{@category}.#{name} — '#{name}' is a #{marker.kind}, but ctx.#{@category} only accepts #{@allowed_kinds.join(', ')}"
      end

      payload = kwargs.empty? ? args.first : kwargs
      @called_markers&.add(name)

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        result = @adapter.execute(name, @ctx, payload)
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
        @trace << TraceEntry.new(
          kind: marker.kind.to_s, category: @category.to_s,
          name: "#{@domain.name}.#{name}", payload: payload,
          status: "pass", duration_ms: elapsed, result: result
        )
        result
      rescue => e
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
        @trace << TraceEntry.new(
          kind: marker.kind.to_s, category: @category.to_s,
          name: "#{@domain.name}.#{name}", payload: payload,
          status: "fail", duration_ms: elapsed, error: e.message
        )
        raise
      end
    end

    def respond_to_missing?(name, include_private = false)
      @domain.markers.key?(name) || super
    end
  end
end

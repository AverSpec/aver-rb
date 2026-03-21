module Aver
  class Context
    attr_reader :given, :when, :then, :query

    def initialize(domain:, adapter:, protocol_ctx:)
      @trace_entries = []
      @called_markers = Set.new

      @given = NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: @trace_entries, category: :given, called_markers: @called_markers)
      @when = NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: @trace_entries, category: :when, called_markers: @called_markers)
      @then = NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: @trace_entries, category: :then, called_markers: @called_markers)
      @query = NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: @trace_entries, category: :query, called_markers: @called_markers)
    end

    def trace
      @trace_entries.dup
    end

    def get_coverage
      markers = @given.instance_variable_get(:@domain).markers
      total = markers.length
      called = @called_markers.length
      percentage = total == 0 ? 100 : (called.to_f / total * 100).round

      { domain: @given.instance_variable_get(:@domain).name, percentage: percentage }
    end
  end
end

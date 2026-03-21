module Aver
  class Context
    attr_reader :given, :when, :then, :query

    def initialize(domain:, adapter:, protocol_ctx:, protocol: nil)
      @domain = domain
      @trace_entries = []
      @called_markers = Set.new

      proxy_opts = { domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, protocol: protocol }
      @given = NarrativeProxy.new(**proxy_opts, trace: @trace_entries, category: :given, called_markers: @called_markers)
      @when = NarrativeProxy.new(**proxy_opts, trace: @trace_entries, category: :when, called_markers: @called_markers)
      @then = NarrativeProxy.new(**proxy_opts, trace: @trace_entries, category: :then, called_markers: @called_markers)
      @query = NarrativeProxy.new(**proxy_opts, trace: @trace_entries, category: :query, called_markers: @called_markers)
    end

    def trace
      @trace_entries.dup
    end

    def get_coverage
      markers = @domain.markers
      total = markers.length
      called = @called_markers.length
      percentage = total == 0 ? 100 : (called.to_f / total * 100).round

      breakdown = { actions: { total: [], called: [] }, queries: { total: [], called: [] }, assertions: { total: [], called: [] } }
      markers.each do |name, marker|
        kind_key = case marker.kind
                   when :action then :actions
                   when :query then :queries
                   when :assertion then :assertions
                   end
        next unless kind_key
        breakdown[kind_key][:total] << name.to_s
        breakdown[kind_key][:called] << name.to_s if @called_markers.include?(name)
      end

      {
        domain: @domain.name,
        percentage: percentage,
        actions: breakdown[:actions],
        queries: breakdown[:queries],
        assertions: breakdown[:assertions],
      }
    end
  end
end

require "set"

module Aver
  class NamespaceProxy
    attr_reader :given, :when, :then, :query

    def initialize(domain:, adapter:, protocol_ctx:, trace:)
      @domain = domain
      @adapter = adapter
      @protocol_ctx = protocol_ctx
      @trace = trace

      @given = NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: trace, category: :given)
      @when = NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: trace, category: :when)
      @then = NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: trace, category: :then)
      @query = NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: trace, category: :query)
    end
  end

  class ComposedContext
    def initialize(namespaces:, trace:)
      @namespaces = namespaces
      @trace_entries = trace
    end

    def trace
      @trace_entries.dup
    end

    def method_missing(name, *args)
      ns = @namespaces[name]
      raise NoMethodError, "No domain namespace '#{name}' in composed suite" unless ns
      ns
    end

    def respond_to_missing?(name, include_private = false)
      @namespaces.key?(name) || super
    end
  end

  def self.composed_suite(config)
    trace = []
    protocol_contexts = {}
    setup_order = []
    namespaces = {}

    config.each do |ns_name, (domain, adapter)|
      proto_ctx = adapter.protocol.setup
      protocol_contexts[ns_name] = proto_ctx
      setup_order << ns_name

      namespaces[ns_name] = NamespaceProxy.new(
        domain: domain,
        adapter: adapter,
        protocol_ctx: proto_ctx,
        trace: trace
      )
    end

    ctx = ComposedContext.new(namespaces: namespaces, trace: trace)

    begin
      yield ctx
    ensure
      setup_order.reverse_each do |ns_name|
        _, adapter = config[ns_name]
        proto_ctx = protocol_contexts[ns_name]
        adapter.protocol.teardown(proto_ctx) if proto_ctx
      end
    end
  end
end

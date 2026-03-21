module Aver
  class Adapter
    attr_reader :domain, :protocol, :handlers

    def initialize(domain:, protocol:, handlers:)
      @domain = domain
      @protocol = protocol
      @handlers = handlers
    end

    def name
      protocol.name
    end

    def domain_name
      domain.name
    end

    def execute(marker_name, ctx, payload = nil)
      handler = handlers[marker_name]
      raise "No handler for #{marker_name}" unless handler
      handler.call(ctx, payload)
    end
  end

  class AdapterBuilder
    attr_reader :domain, :protocol

    def initialize(domain, protocol, &block)
      @domain = domain
      @protocol = protocol
      @handlers = {}
      instance_eval(&block) if block
    end

    def handle(marker_name, &block)
      @handlers[marker_name] = block
    end

    def build
      missing = domain.markers.keys - @handlers.keys
      raise AdapterError, "Missing handlers for: #{missing.join(', ')}" if missing.any?

      extra = @handlers.keys - domain.markers.keys
      raise AdapterError, "Extra handlers not in domain: #{extra.join(', ')}" if extra.any?

      Adapter.new(domain: domain, protocol: protocol, handlers: @handlers)
    end
  end

  class AdapterError < StandardError; end

  def self.implement(domain, protocol:, &block)
    builder = AdapterBuilder.new(domain, protocol, &block)
    builder.build
  end
end

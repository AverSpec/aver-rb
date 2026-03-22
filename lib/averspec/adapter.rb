module Aver
  class AdapterError < StandardError; end

  class Adapter
    class << self
      def domain(klass = nil)
        if klass
          @domain_class = klass
        end
        @domain_class
      end

      def protocol(name_or_protocol = nil, factory = nil)
        if name_or_protocol.is_a?(Symbol) || name_or_protocol.is_a?(String)
          @protocol_name = name_or_protocol.to_s
          @protocol_factory = factory
        elsif name_or_protocol.is_a?(Aver::Protocol)
          @protocol_instance = name_or_protocol
          @protocol_name = name_or_protocol.name
        elsif name_or_protocol.nil?
          # getter
        end
        @protocol_instance || @protocol_name
      end

      def protocol_name
        @protocol_name
      end

      def protocol_factory
        @protocol_factory
      end

      def protocol_instance
        @protocol_instance
      end

      def validate!
        domain_klass = @domain_class
        raise AdapterError, "No domain set on #{self}" unless domain_klass

        domain_markers = if domain_klass.respond_to?(:markers)
          domain_klass.markers.keys
        else
          []
        end

        adapter_methods = instance_methods(false)

        missing = domain_markers - adapter_methods
        raise AdapterError, "Missing handlers: #{missing.join(', ')}" if missing.any?

        extra = adapter_methods.select { |m| !domain_markers.include?(m) && m != :execute }
        raise AdapterError, "Extra handlers not in domain: #{extra.join(', ')}" if extra.any?
      end

      def domain_markers
        if @domain_class.respond_to?(:markers)
          @domain_class.markers
        else
          {}
        end
      end

      def inherited(subclass)
        super
      end
    end

    def execute(marker_name, ctx, payload = nil)
      if payload.is_a?(Hash) && !payload.empty?
        send(marker_name, ctx, **payload)
      elsif payload.nil?
        send(marker_name, ctx)
      else
        send(marker_name, ctx, payload)
      end
    end
  end

  # Alias
  Adapt = Adapter

  # Legacy adapter instance for block-based API (used by Aver.implement)
  class AdapterInstance
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

      AdapterInstance.new(domain: domain, protocol: protocol, handlers: @handlers)
    end
  end

  def self.implement(domain, protocol:, &block)
    builder = AdapterBuilder.new(domain, protocol, &block)
    builder.build
  end

  def self.adapt(domain, protocol:, &block)
    implement(domain, protocol: protocol, &block)
  end

  def self.register(*adapter_classes)
    adapter_classes.each do |klass|
      configuration.register(klass)
    end
  end
end

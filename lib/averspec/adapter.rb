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

  def self.register(*adapter_classes)
    adapter_classes.each do |klass|
      configuration.register(klass)
    end
  end
end

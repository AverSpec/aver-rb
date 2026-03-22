module Aver
  # Wraps an Adapter class so it looks like an adapter instance with .protocol, .execute, etc.
  # Used by aver_test to bridge class-based adapters into the test runner flow.
  class AdapterClassWrapper
    attr_reader :adapter_class

    def initialize(adapter_class)
      @adapter_class = adapter_class
      @instance = adapter_class.new
    end

    def protocol
      @_protocol ||= if adapter_class.protocol_instance
        adapter_class.protocol_instance
      elsif adapter_class.protocol_factory
        Aver::UnitProtocol.new(adapter_class.protocol_factory, name: (adapter_class.protocol_name || "unit").to_s)
      else
        raise "No protocol configured for #{adapter_class}"
      end
    end

    def domain
      adapter_class.domain
    end

    def name
      (adapter_class.protocol_name || "unit").to_s
    end

    def domain_name
      adapter_class.domain&.name || "unknown"
    end

    def execute(marker_name, ctx, payload = nil)
      @instance.execute(marker_name, ctx, payload)
    end
  end

  class Configuration
    attr_accessor :teardown_failure_mode

    def initialize
      @adapter_classes = []
      @teardown_failure_mode = :fail
    end

    # Register an adapter class
    def register(adapter_class)
      if adapter_class.is_a?(Class) && adapter_class < Aver::Adapter
        adapter_class.validate!
        @adapter_classes << adapter_class
      else
        raise ArgumentError, "Expected an Aver::Adapter subclass, got #{adapter_class.class}"
      end
    end

    # Find adapters for a domain — returns wrapped class adapters
    def find_adapters(domain)
      if domain.is_a?(Class) && domain < Aver::Domain
        matches = @adapter_classes.select { |ac| ac.domain == domain }
        matches.map { |ac| AdapterClassWrapper.new(ac) }
      else
        []
      end
    end

    def adapter_classes
      @adapter_classes.dup
    end

    def snapshot
      {
        adapter_classes: @adapter_classes.dup,
        teardown_failure_mode: @teardown_failure_mode,
      }
    end

    def restore(snapshot)
      @adapter_classes = (snapshot[:adapter_classes] || []).dup
      @teardown_failure_mode = snapshot[:teardown_failure_mode]
    end

    def reset!
      @adapter_classes = []
      @teardown_failure_mode = :fail
    end
  end

  @configuration = Configuration.new

  def self.configuration
    @configuration
  end

  def self.configure
    yield @configuration
  end
end

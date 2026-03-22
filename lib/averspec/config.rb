module Aver
  class Configuration
    attr_accessor :adapters, :teardown_failure_mode

    def initialize
      @adapters = []
      @adapter_classes = []
      @teardown_failure_mode = :fail
    end

    # Register an adapter class (OO API) or adapter instance (legacy API)
    def register(adapter)
      if adapter.is_a?(Class) && adapter < Aver::Adapter
        adapter.validate!
        @adapter_classes << adapter
      else
        @adapters << adapter
      end
    end

    # Find adapters for a domain — supports both class-based and instance-based
    def find_adapters(domain)
      # Check class-based adapters first
      class_matches = _find_class_adapters(domain)
      instance_matches = _find_instance_adapters(domain)
      class_matches + instance_matches
    end

    def snapshot
      {
        adapters: @adapters.dup,
        adapter_classes: @adapter_classes.dup,
        teardown_failure_mode: @teardown_failure_mode,
      }
    end

    def restore(snapshot)
      @adapters = snapshot[:adapters].dup
      @adapter_classes = (snapshot[:adapter_classes] || []).dup
      @teardown_failure_mode = snapshot[:teardown_failure_mode]
    end

    def reset!
      @adapters = []
      @adapter_classes = []
      @teardown_failure_mode = :fail
    end

    private

    def _find_class_adapters(domain)
      if domain.is_a?(Class) && domain < Aver::Domain
        @adapter_classes.select { |ac| ac.domain == domain }
      else
        []
      end
    end

    def _find_instance_adapters(domain)
      exact = @adapters.select { |a| a.domain.equal?(domain) }
      return exact if exact.any?

      current = domain.respond_to?(:parent) ? domain.parent : nil
      while current
        parent_matches = @adapters.select { |a| a.domain.equal?(current) }
        return parent_matches if parent_matches.any?
        current = current.respond_to?(:parent) ? current.parent : nil
      end

      []
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

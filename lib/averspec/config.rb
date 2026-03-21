module Aver
  class Configuration
    attr_accessor :adapters, :teardown_failure_mode

    def initialize
      @adapters = []
      @teardown_failure_mode = :fail
    end

    def find_adapters(domain)
      exact = @adapters.select { |a| a.domain.equal?(domain) }
      return exact if exact.any?

      current = domain.parent
      while current
        parent_matches = @adapters.select { |a| a.domain.equal?(current) }
        return parent_matches if parent_matches.any?
        current = current.parent
      end

      []
    end

    def reset!
      @adapters = []
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

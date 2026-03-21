module Aver
  class Protocol
    attr_reader :name
    attr_accessor :telemetry

    def initialize(name: "unknown")
      @name = name
    end

    def setup
      raise NotImplementedError
    end

    def teardown(ctx)
      # no-op by default
    end
  end

  class UnitProtocol < Protocol
    def initialize(factory, name: "unit")
      super(name: name)
      @factory = factory
    end

    def setup
      @factory.call
    end
  end

  def self.unit(name: "unit", &factory)
    UnitProtocol.new(factory, name: name)
  end
end

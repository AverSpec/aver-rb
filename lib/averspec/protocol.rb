module Aver
  # Lifecycle metadata structs
  TestMetadata = Struct.new(:test_name, :domain_name, :adapter_name, keyword_init: true)
  TestCompletion = Struct.new(:test_name, :domain_name, :adapter_name, :status, :error, :trace, keyword_init: true)
  Attachment = Struct.new(:name, :path, :mime, keyword_init: true)

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

    def on_test_start(ctx, meta)
      # no-op by default
    end

    def on_test_end(ctx, meta)
      # no-op by default
    end

    def on_test_fail(ctx, meta)
      # no-op by default; return attachments
      []
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

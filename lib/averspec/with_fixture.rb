module Aver
  class FixtureProtocol < Protocol
    attr_reader :name

    def initialize(inner, before: nil, after_setup: nil, after: nil)
      @inner = inner
      @before_hook = before
      @after_setup_hook = after_setup
      @after_hook = after
      @name = inner.name
    end

    def telemetry
      @inner.telemetry
    end

    def telemetry=(val)
      @inner.telemetry = val
    end

    def setup
      @before_hook&.call
      ctx = @inner.setup
      @after_setup_hook&.call(ctx)
      ctx
    end

    def teardown(ctx)
      begin
        @inner.teardown(ctx)
      ensure
        @after_hook&.call
      end
    end

    def on_test_start(ctx, meta)
      @inner.on_test_start(ctx, meta)
    end

    def on_test_end(ctx, meta)
      @inner.on_test_end(ctx, meta)
    end

    def on_test_fail(ctx, meta)
      @inner.on_test_fail(ctx, meta)
    end
  end

  def self.with_fixture(protocol, before: nil, after_setup: nil, after: nil)
    FixtureProtocol.new(protocol, before: before, after_setup: after_setup, after: after)
  end
end

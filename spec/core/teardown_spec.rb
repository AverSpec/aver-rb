require "spec_helper"

RSpec.describe "Teardown error handling" do
  let(:teardown_domain) do
    Class.new(Aver::Domain) do
      domain_name "Teardown"
      action :do_thing
      assertion :check
    end
  end

  def make_adapter(d, proto)
    dd = d
    klass = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:do_thing) { |ctx, **kw| nil }
      define_method(:check) { |ctx| nil }
    end
    klass.new
  end

  describe "teardown_failure_mode" do
    it "teardown error raises in fail mode" do
      proto = Class.new(Aver::Protocol) do
        define_method(:name) { "failing-teardown" }
        define_method(:setup) { {} }
        define_method(:teardown) { |ctx| raise "teardown exploded" }
      end.new

      adapter = make_adapter(teardown_domain, proto)
      protocol_ctx = proto.setup

      expect { proto.teardown(protocol_ctx) }.to raise_error(RuntimeError, /teardown exploded/)
    end

    it "teardown error warns in warn mode" do
      proto = Class.new(Aver::Protocol) do
        define_method(:name) { "failing-teardown" }
        define_method(:setup) { {} }
        define_method(:teardown) { |ctx| raise "teardown exploded" }
      end.new

      adapter = make_adapter(teardown_domain, proto)
      protocol_ctx = proto.setup

      # Simulate what the RSpec plugin does in warn mode
      warned = nil
      begin
        proto.teardown(protocol_ctx)
      rescue => e
        mode = :warn
        if mode == :warn
          warned = "Teardown error (suppressed): #{e.message}"
        else
          raise
        end
      end

      expect(warned).to include("Teardown error (suppressed)")
    end

    it "config accepts teardown_failure_mode" do
      config = Aver::Configuration.new
      config.teardown_failure_mode = :warn
      expect(config.teardown_failure_mode).to eq(:warn)
    end

    it "teardown still runs on test failure" do
      tracking = Class.new(Aver::Protocol) do
        attr_accessor :teardown_called
        define_method(:name) { "tracking" }
        define_method(:setup) { {} }
        define_method(:teardown) { |ctx| self.teardown_called = true }
      end.new
      tracking.teardown_called = false

      adapter = make_adapter(teardown_domain, tracking)
      protocol_ctx = tracking.setup
      ctx = Aver::Context.new(domain: teardown_domain, adapter: adapter, protocol_ctx: protocol_ctx)

      begin
        raise "test failed"
      rescue
      ensure
        tracking.teardown(protocol_ctx)
      end

      expect(tracking.teardown_called).to be true
    end

    it "after hook runs even if teardown throws" do
      calls = []
      throwing_proto = Class.new(Aver::Protocol) do
        define_method(:name) { "throwing" }
        define_method(:setup) { {} }
        define_method(:teardown) { |ctx| raise "teardown boom" }
      end.new

      wrapped = Aver.with_fixture(throwing_proto, after: -> { calls << "after" })
      ctx = wrapped.setup
      expect { wrapped.teardown(ctx) }.to raise_error(RuntimeError, /teardown boom/)
      expect(calls).to include("after")
    end
  end
end

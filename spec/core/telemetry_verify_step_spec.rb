require "spec_helper"

RSpec.describe "Per-step telemetry verification" do
  let(:domain) do
    Class.new(Aver::Domain) do
      domain_name "Order"
      action :checkout
    end
  end

  let(:fake_collector) do
    Class.new do
      attr_reader :spans

      def initialize(spans = [])
        @spans = spans
      end

      def get_spans
        @spans.dup
      end

      def reset
        @spans.clear
      end
    end
  end

  def make_protocol(collector)
    proto = Aver::Protocol.new(name: "fake")
    proto.define_singleton_method(:setup) { {} }
    proto.define_singleton_method(:teardown) { |ctx| nil }
    proto.telemetry = collector
    proto
  end

  def make_adapter_with_telemetry(d, proto, telemetry_expectation)
    # Set telemetry on the marker
    d.markers.values.first.telemetry = telemetry_expectation

    dd = d
    klass = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:checkout) { |ctx, **kw| "done" }
    end
    klass.new
  end

  around(:each) do |example|
    old_mode = ENV["AVER_TELEMETRY_MODE"]
    example.run
    if old_mode
      ENV["AVER_TELEMETRY_MODE"] = old_mode
    else
      ENV.delete("AVER_TELEMETRY_MODE")
    end
  end

  it "matching span found" do
    ENV["AVER_TELEMETRY_MODE"] = "fail"

    span = Aver::CollectedSpan.new(
      trace_id: "aaa", span_id: "001", name: "order.checkout",
      attributes: { "order.id" => "123" }
    )
    collector = fake_collector.new([span])
    proto = make_protocol(collector)

    expectation = Aver::TelemetryExpectation.new(
      span: "order.checkout",
      attributes: { "order.id" => "123" }
    )
    adapter = make_adapter_with_telemetry(domain, proto, expectation)
    ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: proto.setup, protocol: proto)
    ctx.when.checkout

    entry = ctx.trace[0]
    expect(entry.telemetry).not_to be_nil
    expect(entry.telemetry.matched).to be true
    expect(entry.telemetry.matched_span).not_to be_nil
    expect(entry.telemetry.matched_span.name).to eq("order.checkout")
  end

  it "missing span in fail mode raises" do
    ENV["AVER_TELEMETRY_MODE"] = "fail"

    collector = fake_collector.new([])
    proto = make_protocol(collector)

    expectation = Aver::TelemetryExpectation.new(span: "order.checkout")
    adapter = make_adapter_with_telemetry(domain, proto, expectation)
    ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: proto.setup, protocol: proto)

    expect { ctx.when.checkout }.to raise_error(RuntimeError, /expected span 'order.checkout' not found/)
  end

  it "missing span in warn mode does not raise" do
    ENV["AVER_TELEMETRY_MODE"] = "warn"

    collector = fake_collector.new([])
    proto = make_protocol(collector)

    expectation = Aver::TelemetryExpectation.new(span: "order.checkout")
    adapter = make_adapter_with_telemetry(domain, proto, expectation)
    ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: proto.setup, protocol: proto)

    expect { ctx.when.checkout }.not_to raise_error
    entry = ctx.trace[0]
    expect(entry.telemetry).not_to be_nil
    expect(entry.telemetry.matched).to be false
  end

  it "parameterized telemetry" do
    ENV["AVER_TELEMETRY_MODE"] = "fail"

    span = Aver::CollectedSpan.new(
      trace_id: "aaa", span_id: "001", name: "order.checkout",
      attributes: { "order.id" => "ORD-42" }
    )
    collector = fake_collector.new([span])
    proto = make_protocol(collector)

    # Set callable telemetry
    d = Class.new(Aver::Domain) do
      domain_name "ParamOrder"
      action :checkout
    end
    d.markers[:checkout].telemetry = ->(payload) {
      Aver::TelemetryExpectation.new(
        span: "order.checkout",
        attributes: { "order.id" => payload[:order_id] }
      )
    }
    dd = d
    klass = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:checkout) { |ctx, **kw| "done" }
    end
    adapter = klass.new
    ctx = Aver::Context.new(domain: d, adapter: adapter, protocol_ctx: proto.setup, protocol: proto)
    ctx.when.checkout(order_id: "ORD-42")

    entry = ctx.trace[0]
    expect(entry.telemetry).not_to be_nil
    expect(entry.telemetry.matched).to be true
  end

  it "no telemetry on marker skips verification" do
    collector = fake_collector.new([])
    proto = make_protocol(collector)

    d = Class.new(Aver::Domain) do
      domain_name "NoTel"
      action :checkout
    end
    # No telemetry set on marker
    dd = d
    klass = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:checkout) { |ctx, **kw| "done" }
    end
    adapter = klass.new
    ctx = Aver::Context.new(domain: d, adapter: adapter, protocol_ctx: proto.setup, protocol: proto)
    ctx.when.checkout

    entry = ctx.trace[0]
    expect(entry.telemetry).to be_nil
  end

  it "no collector on protocol skips verification" do
    proto = Aver::Protocol.new(name: "no-collector")
    proto.define_singleton_method(:setup) { {} }
    proto.define_singleton_method(:teardown) { |ctx| nil }
    # proto.telemetry is nil

    d = Class.new(Aver::Domain) do
      domain_name "NoCollector"
      action :checkout
    end
    d.markers[:checkout].telemetry = Aver::TelemetryExpectation.new(span: "order.checkout")
    dd = d
    klass = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:checkout) { |ctx, **kw| "done" }
    end
    adapter = klass.new
    ctx = Aver::Context.new(domain: d, adapter: adapter, protocol_ctx: proto.setup, protocol: proto)
    ctx.when.checkout

    entry = ctx.trace[0]
    expect(entry.telemetry).to be_nil
  end

  it "off mode skips verification even with collector" do
    ENV["AVER_TELEMETRY_MODE"] = "off"

    collector = fake_collector.new([])
    proto = make_protocol(collector)

    d = Class.new(Aver::Domain) do
      domain_name "OffMode"
      action :checkout
    end
    d.markers[:checkout].telemetry = Aver::TelemetryExpectation.new(span: "order.checkout")
    dd = d
    klass = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:checkout) { |ctx, **kw| "done" }
    end
    adapter = klass.new
    ctx = Aver::Context.new(domain: d, adapter: adapter, protocol_ctx: proto.setup, protocol: proto)
    ctx.when.checkout

    entry = ctx.trace[0]
    expect(entry.telemetry).to be_nil
  end
end

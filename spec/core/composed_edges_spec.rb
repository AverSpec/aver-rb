require "spec_helper"

RSpec.describe "Composed suite edge cases" do
  def tracking_proto(label, setup_log, teardown_log, fail_setup: false)
    proto = Class.new(Aver::Protocol) do
      define_method(:name) { label }
      define_method(:setup) do
        setup_log << "setup:#{label}"
        raise "setup failed: #{label}" if fail_setup
        { label: label }
      end
      define_method(:teardown) { |ctx| teardown_log << "teardown:#{label}" }
    end.new
    proto
  end

  def build_adapter(d, proto)
    handlers = {}
    d.markers.each_key { |name| handlers[name] = ->(ctx, payload) { nil } }
    Aver::AdapterInstance.new(domain: d, protocol: proto, handlers: handlers)
  end

  it "partial setup failure tears down already-setup domains" do
    setup_log = []
    teardown_log = []

    d1 = Aver.domain("Alpha") { action :a1 }
    d2 = Aver.domain("Beta") { action :a2 }

    proto_a = tracking_proto("alpha", setup_log, teardown_log)
    proto_b = tracking_proto("beta", setup_log, teardown_log, fail_setup: true)

    adapter_a = build_adapter(d1, proto_a)
    adapter_b = build_adapter(d2, proto_b)

    expect {
      Aver.composed_suite(alpha: [d1, adapter_a], beta: [d2, adapter_b]) do |ctx|
        # body should not execute
      end
    }.to raise_error(RuntimeError, /setup failed: beta/)

    expect(setup_log).to include("setup:alpha")
    expect(setup_log).to include("setup:beta")
    expect(teardown_log).to include("teardown:alpha")
  end

  it "trace entries carry domain prefix" do
    setup_log = []
    teardown_log = []

    d1 = Aver.domain("Alpha") { action :do_thing }
    d2 = Aver.domain("Beta") { action :do_other }

    proto_a = tracking_proto("alpha", setup_log, teardown_log)
    proto_b = tracking_proto("beta", setup_log, teardown_log)

    adapter_a = build_adapter(d1, proto_a)
    adapter_b = build_adapter(d2, proto_b)

    traces = []
    Aver.composed_suite(alpha: [d1, adapter_a], beta: [d2, adapter_b]) do |ctx|
      ctx.alpha.when.do_thing
      ctx.beta.when.do_other
      traces.concat(ctx.trace)
    end

    expect(traces.length).to eq(2)
    expect(traces[0].name).to eq("Alpha.do_thing")
    expect(traces[1].name).to eq("Beta.do_other")
  end

  it "teardown in reverse order" do
    setup_log = []
    teardown_log = []

    d1 = Aver.domain("First") { action :a1 }
    d2 = Aver.domain("Second") { action :a2 }

    proto_a = tracking_proto("first", setup_log, teardown_log)
    proto_b = tracking_proto("second", setup_log, teardown_log)

    adapter_a = build_adapter(d1, proto_a)
    adapter_b = build_adapter(d2, proto_b)

    Aver.composed_suite(first: [d1, adapter_a], second: [d2, adapter_b]) do |ctx|
      ctx.first.when.a1
    end

    expect(teardown_log).to eq(["teardown:second", "teardown:first"])
  end
end

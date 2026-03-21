require "spec_helper"

RSpec.describe "Telemetry acceptance" do
  around(:each) do |example|
    old_mode = ENV["AVER_TELEMETRY_MODE"]
    example.run
    if old_mode
      ENV["AVER_TELEMETRY_MODE"] = old_mode
    else
      ENV.delete("AVER_TELEMETRY_MODE")
    end
  end

  it "span matching in full context" do
    ENV["AVER_TELEMETRY_MODE"] = "fail"

    d = Aver.domain("TelAccept") do
      action :checkout
    end

    span = Aver::CollectedSpan.new(
      trace_id: "t1", span_id: "s1", name: "order.checkout",
      attributes: { "order.id" => "42" }
    )
    collector = Object.new
    collector.define_singleton_method(:get_spans) { [span] }
    collector.define_singleton_method(:reset) { nil }

    proto = Aver::Protocol.new(name: "tel-test")
    proto.define_singleton_method(:setup) { {} }
    proto.define_singleton_method(:teardown) { |ctx| nil }
    proto.telemetry = collector

    d.markers[:checkout].telemetry = Aver::TelemetryExpectation.new(
      span: "order.checkout",
      attributes: { "order.id" => "42" }
    )

    a = Aver.implement(d, protocol: proto) do
      handle(:checkout) { |ctx, p| "done" }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup, protocol: proto)
    ctx.when.checkout

    entry = ctx.trace[0]
    expect(entry.telemetry).not_to be_nil
    expect(entry.telemetry.matched).to be true
    expect(entry.telemetry.matched_span.attributes["order.id"]).to eq("42")
  end
end

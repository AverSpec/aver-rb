require "spec_helper"

TelemetryDomain = Aver.domain("telemetry-test") do
  action :run_span_matching
  assertion :span_matched_correctly
end

TelemetryAdapter = Aver.implement(TelemetryDomain, protocol: Aver.unit { {} }) do
  handle(:run_span_matching) do |state, p|
    old_mode = ENV["AVER_TELEMETRY_MODE"]
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

    state[:trace_entry] = ctx.trace[0]
  ensure
    if old_mode
      ENV["AVER_TELEMETRY_MODE"] = old_mode
    else
      ENV.delete("AVER_TELEMETRY_MODE")
    end
  end

  handle(:span_matched_correctly) do |state, p|
    entry = state[:trace_entry]
    raise "Expected telemetry to be present" if entry.telemetry.nil?
    raise "Expected telemetry.matched to be true" unless entry.telemetry.matched == true
    raise "Expected order.id '42', got '#{entry.telemetry.matched_span.attributes["order.id"]}'" unless entry.telemetry.matched_span.attributes["order.id"] == "42"
  end
end

Aver.configuration.adapters << TelemetryAdapter

RSpec.describe "Telemetry acceptance", aver: TelemetryDomain do

  aver_test "span matching in full context" do |ctx|
    ctx.when.run_span_matching
    ctx.then.span_matched_correctly
  end
end

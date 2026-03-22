require "spec_helper"

class TelAcceptDomain < Aver::Domain
  domain_name "telemetry-test"
  action :run_span_matching
  assertion :span_matched_correctly
end

class TelAcceptAdapter < Aver::Adapter
  domain TelAcceptDomain
  protocol :unit, -> { {} }

  def run_span_matching(state, **kw)
    old_mode = ENV["AVER_TELEMETRY_MODE"]
    ENV["AVER_TELEMETRY_MODE"] = "fail"

    d = Class.new(Aver::Domain) do
      domain_name "TelAccept"
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

    dd = d
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:checkout) { |ctx, **k| "done" }
    end.new
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

  def span_matched_correctly(state, **kw)
    entry = state[:trace_entry]
    raise "Expected telemetry to be present" if entry.telemetry.nil?
    raise "Expected telemetry.matched to be true" unless entry.telemetry.matched == true
    raise "Expected order.id '42', got '#{entry.telemetry.matched_span.attributes["order.id"]}'" unless entry.telemetry.matched_span.attributes["order.id"] == "42"
  end
end

Aver.register(TelAcceptAdapter)

RSpec.describe "Telemetry acceptance", aver: TelAcceptDomain do

  aver_test "span matching in full context" do |ctx|
    ctx.when.run_span_matching
    ctx.then.span_matched_correctly
  end
end

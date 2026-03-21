require "spec_helper"

RSpec.describe "Aver.verify_correlation" do
  def make_entry(name:, span_name:, attributes:, trace_id: "t1", span_id: "s1", causes: [], parent_span_id: nil)
    expected = Aver::TelemetryExpectation.new(
      span: span_name,
      attributes: attributes,
      causes: causes
    )
    matched_span = Aver::CollectedSpan.new(
      trace_id: trace_id,
      span_id: span_id,
      name: span_name,
      attributes: attributes,
      parent_span_id: parent_span_id
    )
    telem = Aver::TelemetryMatchResult.new(
      expected: expected,
      matched: true,
      matched_span: matched_span
    )
    entry = Aver::TraceEntry.new(
      kind: "action", category: "when", name: name,
      status: "pass", duration_ms: 1.0
    )
    entry.telemetry = telem
    entry
  end

  it "returns empty result when no telemetry is present" do
    entry = Aver::TraceEntry.new(kind: "action", category: "when", name: "op", status: "pass")
    result = Aver.verify_correlation([entry])
    expect(result.groups).to be_empty
    expect(result.violations).to be_empty
  end

  it "groups steps by shared attribute key/value" do
    e1 = make_entry(name: "tasks.create", span_name: "create", attributes: { "user.id" => "42" }, span_id: "s1")
    e2 = make_entry(name: "tasks.verify", span_name: "verify", attributes: { "user.id" => "42" }, span_id: "s2")
    result = Aver.verify_correlation([e1, e2])
    expect(result.groups.length).to eq(1)
    expect(result.groups[0].key).to eq("user.id")
    expect(result.groups[0].value).to eq("42")
  end

  it "reports attribute mismatch when span lacks expected attribute" do
    expected = Aver::TelemetryExpectation.new(
      span: "op", attributes: { "key" => "val" }
    )
    matched_span = Aver::CollectedSpan.new(
      trace_id: "t1", span_id: "s1", name: "op", attributes: {}
    )
    telem = Aver::TelemetryMatchResult.new(expected: expected, matched: true, matched_span: matched_span)

    e1 = Aver::TraceEntry.new(kind: "action", category: "when", name: "a", status: "pass")
    e1.telemetry = telem

    e2 = make_entry(name: "b", span_name: "op2", attributes: { "key" => "val" }, span_id: "s2")
    result = Aver.verify_correlation([e1, e2])
    expect(result.violations.any? { |v| v.kind == "attribute-mismatch" }).to be true
  end

  it "detects causal break across different traces" do
    e1 = make_entry(
      name: "tasks.create", span_name: "create",
      attributes: { "flow" => "x" },
      trace_id: "t1", span_id: "s1"
    )
    e2 = make_entry(
      name: "tasks.notify", span_name: "notify",
      attributes: { "flow" => "x" },
      trace_id: "t2", span_id: "s2",
      causes: ["create"]
    )
    result = Aver.verify_correlation([e1, e2])
    expect(result.violations.any? { |v| v.kind == "causal-break" }).to be true
  end

  it "passes causal check when in same trace" do
    e1 = make_entry(
      name: "tasks.create", span_name: "create",
      attributes: { "flow" => "x" },
      trace_id: "t1", span_id: "s1"
    )
    e2 = make_entry(
      name: "tasks.notify", span_name: "notify",
      attributes: { "flow" => "x" },
      trace_id: "t1", span_id: "s2",
      causes: ["create"]
    )
    result = Aver.verify_correlation([e1, e2])
    causal_breaks = result.violations.select { |v| v.kind == "causal-break" }
    expect(causal_breaks).to be_empty
  end

  it "passes causal check when spans are linked" do
    e1_expected = Aver::TelemetryExpectation.new(span: "create", attributes: { "flow" => "x" })
    e1_span = Aver::CollectedSpan.new(
      trace_id: "t1", span_id: "s1", name: "create",
      attributes: { "flow" => "x" },
      links: [Aver::SpanLink.new(trace_id: "t2", span_id: "s2")]
    )
    e1_telem = Aver::TelemetryMatchResult.new(expected: e1_expected, matched: true, matched_span: e1_span)
    e1 = Aver::TraceEntry.new(kind: "action", category: "when", name: "tasks.create", status: "pass")
    e1.telemetry = e1_telem

    e2 = make_entry(
      name: "tasks.notify", span_name: "notify",
      attributes: { "flow" => "x" },
      trace_id: "t2", span_id: "s2",
      causes: ["create"]
    )
    result = Aver.verify_correlation([e1, e2])
    causal_breaks = result.violations.select { |v| v.kind == "causal-break" }
    expect(causal_breaks).to be_empty
  end
end

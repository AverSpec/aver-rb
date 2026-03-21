require "spec_helper"

RSpec.describe "Telemetry Types" do
  describe Aver::SpanLink do
    it "stores trace_id and span_id" do
      link = Aver::SpanLink.new(trace_id: "abc", span_id: "123")
      expect(link.trace_id).to eq("abc")
      expect(link.span_id).to eq("123")
    end
  end

  describe Aver::CollectedSpan do
    it "stores all fields" do
      span = Aver::CollectedSpan.new(
        trace_id: "t1", span_id: "s1", name: "http.request",
        attributes: { "http.method" => "GET" },
        parent_span_id: "p1",
        links: [Aver::SpanLink.new(trace_id: "t2", span_id: "s2")]
      )
      expect(span.name).to eq("http.request")
      expect(span.attributes["http.method"]).to eq("GET")
      expect(span.parent_span_id).to eq("p1")
      expect(span.links.length).to eq(1)
    end

    it "defaults optional fields" do
      span = Aver::CollectedSpan.new(trace_id: "t1", span_id: "s1", name: "op")
      expect(span.attributes).to eq({})
      expect(span.parent_span_id).to be_nil
      expect(span.links).to eq([])
    end
  end

  describe Aver::TelemetryExpectation do
    it "stores span name and attributes" do
      exp = Aver::TelemetryExpectation.new(
        span: "task.create",
        attributes: { "task.title" => "test" },
        causes: ["task.validate"]
      )
      expect(exp.span).to eq("task.create")
      expect(exp.attributes["task.title"]).to eq("test")
      expect(exp.causes).to eq(["task.validate"])
    end
  end

  describe Aver::TelemetryMatchResult do
    it "stores match result with matched span" do
      expected = Aver::TelemetryExpectation.new(span: "op")
      matched_span = Aver::CollectedSpan.new(trace_id: "t", span_id: "s", name: "op")
      result = Aver::TelemetryMatchResult.new(
        expected: expected, matched: true, matched_span: matched_span
      )
      expect(result.matched).to be true
      expect(result.matched_span.name).to eq("op")
    end
  end
end

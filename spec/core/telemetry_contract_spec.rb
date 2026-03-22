require "spec_helper"

RSpec.describe "Aver.extract_contract" do
  let(:domain) do
    Class.new(Aver::Domain) do
      domain_name "tasks"
      action :create_task
      assertion :task_exists
    end
  end

  def make_trace_entry(name:, span:, attributes: {}, span_id: "s1", parent_span_id: nil)
    expected = Aver::TelemetryExpectation.new(span: span, attributes: attributes)
    matched = Aver::CollectedSpan.new(
      trace_id: "t1", span_id: span_id, name: span,
      attributes: attributes, parent_span_id: parent_span_id
    )
    telem = Aver::TelemetryMatchResult.new(expected: expected, matched: true, matched_span: matched)
    entry = Aver::TraceEntry.new(kind: "action", category: "when", name: name, status: "pass")
    entry.telemetry = telem
    entry
  end

  it "extracts spans from trace entries" do
    trace = [
      make_trace_entry(name: "tasks.create_task", span: "task.create", attributes: { "task.title" => "test" })
    ]
    contract = Aver.extract_contract(domain, [{ test_name: "create test", trace: trace }])
    expect(contract.entries.length).to eq(1)
    expect(contract.entries[0].spans.length).to eq(1)
    expect(contract.entries[0].spans[0].name).to eq("task.create")
  end

  it "sets domain name on contract" do
    contract = Aver.extract_contract(domain, [])
    expect(contract.domain).to eq("tasks")
  end

  it "creates literal attribute bindings" do
    trace = [
      make_trace_entry(name: "tasks.create_task", span: "task.create", attributes: { "kind" => "bug" })
    ]
    contract = Aver.extract_contract(domain, [{ test_name: "t", trace: trace }])
    binding = contract.entries[0].spans[0].attributes["kind"]
    expect(binding.kind).to eq("literal")
    expect(binding.value).to eq("bug")
  end

  it "skips entries without telemetry" do
    entry = Aver::TraceEntry.new(kind: "action", category: "when", name: "tasks.create_task", status: "pass")
    contract = Aver.extract_contract(domain, [{ test_name: "t", trace: [entry] }])
    expect(contract.entries).to be_empty
  end

  it "resolves parent name from span hierarchy" do
    trace = [
      make_trace_entry(name: "tasks.create_task", span: "task.create", span_id: "parent1"),
      make_trace_entry(name: "tasks.task_exists", span: "task.verify", span_id: "child1", parent_span_id: "parent1")
    ]
    contract = Aver.extract_contract(domain, [{ test_name: "t", trace: trace }])
    expect(contract.entries[0].spans[1].parent_name).to eq("task.create")
  end

  it "handles multiple test results" do
    trace1 = [make_trace_entry(name: "tasks.create_task", span: "task.create")]
    trace2 = [make_trace_entry(name: "tasks.task_exists", span: "task.verify")]
    contract = Aver.extract_contract(domain, [
      { test_name: "test1", trace: trace1 },
      { test_name: "test2", trace: trace2 },
    ])
    expect(contract.entries.length).to eq(2)
  end
end

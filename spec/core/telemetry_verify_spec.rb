require "spec_helper"
require "set"

RSpec.describe "Aver.verify_contract" do
  def make_contract(domain:, entries:)
    Aver::BehavioralContract.new(domain: domain, entries: entries)
  end

  def make_entry(test_name:, spans:)
    Aver::ContractEntry.new(test_name: test_name, spans: spans)
  end

  def make_span(name:, attributes: {}, parent_name: nil)
    Aver::SpanExpectation.new(name: name, attributes: attributes, parent_name: parent_name)
  end

  def make_prod_trace(trace_id:, spans:)
    Aver::ProductionTrace.new(trace_id: trace_id, spans: spans)
  end

  def make_prod_span(name:, attributes: {}, span_id: nil, parent_span_id: nil)
    Aver::ProductionSpan.new(name: name, attributes: attributes, span_id: span_id, parent_span_id: parent_span_id)
  end

  it "returns clean report when contract matches traces" do
    contract = make_contract(
      domain: "tasks",
      entries: [
        make_entry(test_name: "create", spans: [
          make_span(name: "task.create")
        ])
      ]
    )
    traces = [
      make_prod_trace(trace_id: "t1", spans: [
        make_prod_span(name: "task.create", span_id: "s1")
      ])
    ]
    report = Aver.verify_contract(contract, traces)
    expect(report.total_violations).to eq(0)
    expect(report.results[0].traces_matched).to eq(1)
  end

  it "reports missing span" do
    contract = make_contract(
      domain: "tasks",
      entries: [
        make_entry(test_name: "create", spans: [
          make_span(name: "task.create"),
          make_span(name: "task.validate")
        ])
      ]
    )
    traces = [
      make_prod_trace(trace_id: "t1", spans: [
        make_prod_span(name: "task.create", span_id: "s1")
      ])
    ]
    report = Aver.verify_contract(contract, traces)
    missing = report.results[0].violations.select { |v| v.kind == "missing-span" }
    expect(missing.length).to eq(1)
    expect(missing[0].span_name).to eq("task.validate")
  end

  it "reports literal attribute mismatch" do
    contract = make_contract(
      domain: "tasks",
      entries: [
        make_entry(test_name: "create", spans: [
          make_span(name: "task.create", attributes: {
            "status" => Aver::AttributeBinding.new(kind: "literal", value: "active")
          })
        ])
      ]
    )
    traces = [
      make_prod_trace(trace_id: "t1", spans: [
        make_prod_span(name: "task.create", span_id: "s1", attributes: { "status" => "inactive" })
      ])
    ]
    report = Aver.verify_contract(contract, traces)
    mismatches = report.results[0].violations.select { |v| v.kind == "literal-mismatch" }
    expect(mismatches.length).to eq(1)
  end

  it "reports no-matching-traces when anchor not found" do
    contract = make_contract(
      domain: "tasks",
      entries: [
        make_entry(test_name: "create", spans: [
          make_span(name: "task.create")
        ])
      ]
    )
    report = Aver.verify_contract(contract, [])
    no_match = report.results[0].violations.select { |v| v.kind == "no-matching-traces" }
    expect(no_match.length).to eq(1)
  end

  it "detects correlation violation" do
    contract = make_contract(
      domain: "tasks",
      entries: [
        make_entry(test_name: "flow", spans: [
          make_span(name: "task.create", attributes: {
            "user" => Aver::AttributeBinding.new(kind: "correlated", symbol: "$user")
          }),
          make_span(name: "task.notify", attributes: {
            "user" => Aver::AttributeBinding.new(kind: "correlated", symbol: "$user")
          })
        ])
      ]
    )
    traces = [
      make_prod_trace(trace_id: "t1", spans: [
        make_prod_span(name: "task.create", span_id: "s1", attributes: { "user" => "alice" }),
        make_prod_span(name: "task.notify", span_id: "s2", attributes: { "user" => "bob" })
      ])
    ]
    report = Aver.verify_contract(contract, traces)
    corr = report.results[0].violations.select { |v| v.kind == "correlation-violation" }
    expect(corr.length).to eq(1)
  end

  it "passes correlation when values match" do
    contract = make_contract(
      domain: "tasks",
      entries: [
        make_entry(test_name: "flow", spans: [
          make_span(name: "task.create", attributes: {
            "user" => Aver::AttributeBinding.new(kind: "correlated", symbol: "$user")
          }),
          make_span(name: "task.notify", attributes: {
            "user" => Aver::AttributeBinding.new(kind: "correlated", symbol: "$user")
          })
        ])
      ]
    )
    traces = [
      make_prod_trace(trace_id: "t1", spans: [
        make_prod_span(name: "task.create", span_id: "s1", attributes: { "user" => "alice" }),
        make_prod_span(name: "task.notify", span_id: "s2", attributes: { "user" => "alice" })
      ])
    ]
    report = Aver.verify_contract(contract, traces)
    expect(report.total_violations).to eq(0)
  end
end

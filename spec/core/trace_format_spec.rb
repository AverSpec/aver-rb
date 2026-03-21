require "spec_helper"

RSpec.describe "Aver.format_trace" do
  it "formats a passing action entry" do
    entry = Aver::TraceEntry.new(
      kind: "action", category: "when", name: "tasks.create_task",
      payload: { title: "test" }, status: "pass", duration_ms: 3.0
    )
    output = Aver.format_trace([entry])
    expect(output).to include("[PASS]")
    expect(output).to include("WHEN")
    expect(output).to include("tasks.create_task")
    expect(output).to include("3ms")
  end

  it "formats a failing entry with error message" do
    entry = Aver::TraceEntry.new(
      kind: "assertion", category: "then", name: "tasks.task_exists",
      payload: nil, status: "fail", duration_ms: 1.0, error: "not found"
    )
    output = Aver.format_trace([entry])
    expect(output).to include("[FAIL]")
    expect(output).to include("THEN")
    expect(output).to include("-- not found")
  end

  it "truncates long payloads on passing entries" do
    long_payload = { data: "x" * 100 }
    entry = Aver::TraceEntry.new(
      kind: "action", category: "when", name: "tasks.bulk_op",
      payload: long_payload, status: "pass", duration_ms: 2.0
    )
    output = Aver.format_trace([entry])
    expect(output).to include("...")
    # The payload should be truncated to ~60 chars
    payload_part = output.match(/\((.+)\)/)[1]
    expect(payload_part.length).to be <= 60
  end

  it "shows full payload on failing entries" do
    long_payload = { data: "x" * 100 }
    entry = Aver::TraceEntry.new(
      kind: "action", category: "when", name: "tasks.bulk_op",
      payload: long_payload, status: "fail", duration_ms: 2.0, error: "boom"
    )
    output = Aver.format_trace([entry])
    expect(output).not_to match(/\.\.\.\)/)
  end

  it "falls back to kind-based label when category is nil" do
    entry = Aver::TraceEntry.new(
      kind: "query", category: nil, name: "tasks.get_task",
      status: "pass", duration_ms: 1.0
    )
    output = Aver.format_trace([entry])
    expect(output).to include("QUERY")
  end

  it "formats multiple entries on separate lines" do
    entries = [
      Aver::TraceEntry.new(kind: "action", category: "when", name: "tasks.create", status: "pass", duration_ms: 1.0),
      Aver::TraceEntry.new(kind: "assertion", category: "then", name: "tasks.exists", status: "pass", duration_ms: 2.0),
    ]
    output = Aver.format_trace(entries)
    lines = output.split("\n")
    expect(lines.length).to eq(2)
  end
end

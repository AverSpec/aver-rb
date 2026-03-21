require "spec_helper"

ActionTraceDomain = Aver.domain("action-trace") do
  action :run_full_trace_scenario
  action :run_failure_scenario
  action :run_categorized_scenario
  action :run_empty_trace_scenario
  assertion :trace_has_correct_kinds_and_categories
  assertion :trace_records_failure_status
  assertion :trace_has_given_when_then_categories
  assertion :trace_is_empty
end

ActionTraceAdapter = Aver.implement(ActionTraceDomain, protocol: Aver.unit { {} }) do
  handle(:run_full_trace_scenario) do |state, p|
    d = Aver.domain("trace-full") do
      action :setup_data
      query :fetch_data, returns: Hash
      assertion :data_valid
    end
    proto = Aver.unit { {} }
    a = Aver.implement(d, protocol: proto) do
      handle(:setup_data) { |ctx, payload| ctx[:data] = payload }
      handle(:fetch_data) { |ctx, payload| ctx[:data] }
      handle(:data_valid) { |ctx, payload| true }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.when.setup_data(seed: "abc")
    ctx.query.fetch_data
    ctx.then.data_valid
    state[:trace] = ctx.trace
  end

  handle(:run_failure_scenario) do |state, p|
    d = Aver.domain("trace-fail") do
      action :prepare
      assertion :check_result
    end
    proto = Aver.unit { {} }
    a = Aver.implement(d, protocol: proto) do
      handle(:prepare) { |ctx, payload| nil }
      handle(:check_result) { |ctx, payload| raise "check failed" }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.when.prepare(data: "seed")
    begin
      ctx.then.check_result
    rescue
    end
    state[:trace] = ctx.trace
  end

  handle(:run_categorized_scenario) do |state, p|
    d = Aver.domain("trace-cat") do
      action :seed_state
      action :perform_action
      assertion :verify_outcome
    end
    proto = Aver.unit { {} }
    a = Aver.implement(d, protocol: proto) do
      handle(:seed_state) { |ctx, payload| nil }
      handle(:perform_action) { |ctx, payload| nil }
      handle(:verify_outcome) { |ctx, payload| nil }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.given.seed_state(data: "initial")
    ctx.when.perform_action(data: "go")
    ctx.then.verify_outcome
    state[:trace] = ctx.trace
  end

  handle(:run_empty_trace_scenario) do |state, p|
    d = Aver.domain("trace-empty") do
      action :noop
    end
    proto = Aver.unit { {} }
    a = Aver.implement(d, protocol: proto) do
      handle(:noop) { |ctx, payload| nil }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    state[:trace] = ctx.trace
  end

  handle(:trace_has_correct_kinds_and_categories) do |state, p|
    trace = state[:trace]
    raise "Expected 3 trace entries, got #{trace.length}" unless trace.length == 3
    raise "Expected entry 0 kind 'action', got '#{trace[0].kind}'" unless trace[0].kind == "action"
    raise "Expected entry 0 category 'when', got '#{trace[0].category}'" unless trace[0].category == "when"
    raise "Expected entry 0 status 'pass', got '#{trace[0].status}'" unless trace[0].status == "pass"
    raise "Expected entry 1 kind 'query', got '#{trace[1].kind}'" unless trace[1].kind == "query"
    raise "Expected entry 1 category 'query', got '#{trace[1].category}'" unless trace[1].category == "query"
    raise "Expected entry 2 kind 'assertion', got '#{trace[2].kind}'" unless trace[2].kind == "assertion"
    raise "Expected entry 2 category 'then', got '#{trace[2].category}'" unless trace[2].category == "then"
  end

  handle(:trace_records_failure_status) do |state, p|
    trace = state[:trace]
    raise "Expected 2 trace entries, got #{trace.length}" unless trace.length == 2
    raise "Expected entry 0 status 'pass', got '#{trace[0].status}'" unless trace[0].status == "pass"
    raise "Expected entry 1 status 'fail', got '#{trace[1].status}'" unless trace[1].status == "fail"
  end

  handle(:trace_has_given_when_then_categories) do |state, p|
    trace = state[:trace]
    raise "Expected 3 trace entries, got #{trace.length}" unless trace.length == 3
    raise "Expected entry 0 category 'given', got '#{trace[0].category}'" unless trace[0].category == "given"
    raise "Expected entry 1 category 'when', got '#{trace[1].category}'" unless trace[1].category == "when"
    raise "Expected entry 2 category 'then', got '#{trace[2].category}'" unless trace[2].category == "then"
  end

  handle(:trace_is_empty) do |state, p|
    trace = state[:trace]
    raise "Expected empty trace, got #{trace.length} entries" unless trace.empty?
  end
end

Aver.configuration.adapters << ActionTraceAdapter

RSpec.describe "Action trace acceptance", aver: ActionTraceDomain do

  aver_test "records complete trace across multiple operation types" do |ctx|
    ctx.when.run_full_trace_scenario
    ctx.then.trace_has_correct_kinds_and_categories
  end

  aver_test "records failure status when assertion fails" do |ctx|
    ctx.when.run_failure_scenario
    ctx.then.trace_records_failure_status
  end

  aver_test "records categorized trace with given/when/then" do |ctx|
    ctx.when.run_categorized_scenario
    ctx.then.trace_has_given_when_then_categories
  end

  aver_test "trace is empty before any operations" do |ctx|
    ctx.when.run_empty_trace_scenario
    ctx.then.trace_is_empty
  end
end

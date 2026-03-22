require "spec_helper"

class ActionTraceDomain < Aver::Domain
  domain_name "action-trace"
  action :run_full_trace_scenario
  action :run_failure_scenario
  action :run_categorized_scenario
  action :run_empty_trace_scenario
  assertion :trace_has_correct_kinds_and_categories
  assertion :trace_records_failure_status
  assertion :trace_has_given_when_then_categories
  assertion :trace_is_empty
end

class ActionTraceAdapter < Aver::Adapter
  domain ActionTraceDomain
  protocol :unit, -> { {} }

  def run_full_trace_scenario(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "trace-full"
      action :setup_data
      query :fetch_data, returns: Hash
      assertion :data_valid
    end
    dd = d
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:setup_data) { |ctx, **k| ctx[:data] = k }
      define_method(:fetch_data) { |ctx| ctx[:data] }
      define_method(:data_valid) { |ctx| true }
    end.new
    proto = Aver::UnitProtocol.new(-> { {} }, name: "unit")
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.when.setup_data(seed: "abc")
    ctx.query.fetch_data
    ctx.then.data_valid
    state[:trace] = ctx.trace
  end

  def run_failure_scenario(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "trace-fail"
      action :prepare
      assertion :check_result
    end
    dd = d
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:prepare) { |ctx, **k| nil }
      define_method(:check_result) { |ctx| raise "check failed" }
    end.new
    proto = Aver::UnitProtocol.new(-> { {} }, name: "unit")
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.when.prepare(data: "seed")
    begin
      ctx.then.check_result
    rescue
    end
    state[:trace] = ctx.trace
  end

  def run_categorized_scenario(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "trace-cat"
      action :seed_state
      action :perform_action
      assertion :verify_outcome
    end
    dd = d
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:seed_state) { |ctx, **k| nil }
      define_method(:perform_action) { |ctx, **k| nil }
      define_method(:verify_outcome) { |ctx| nil }
    end.new
    proto = Aver::UnitProtocol.new(-> { {} }, name: "unit")
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.given.seed_state(data: "initial")
    ctx.when.perform_action(data: "go")
    ctx.then.verify_outcome
    state[:trace] = ctx.trace
  end

  def run_empty_trace_scenario(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "trace-empty"
      action :noop
    end
    dd = d
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:noop) { |ctx, **k| nil }
    end.new
    proto = Aver::UnitProtocol.new(-> { {} }, name: "unit")
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    state[:trace] = ctx.trace
  end

  def trace_has_correct_kinds_and_categories(state, **kw)
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

  def trace_records_failure_status(state, **kw)
    trace = state[:trace]
    raise "Expected 2 trace entries, got #{trace.length}" unless trace.length == 2
    raise "Expected entry 0 status 'pass', got '#{trace[0].status}'" unless trace[0].status == "pass"
    raise "Expected entry 1 status 'fail', got '#{trace[1].status}'" unless trace[1].status == "fail"
  end

  def trace_has_given_when_then_categories(state, **kw)
    trace = state[:trace]
    raise "Expected 3 trace entries, got #{trace.length}" unless trace.length == 3
    raise "Expected entry 0 category 'given', got '#{trace[0].category}'" unless trace[0].category == "given"
    raise "Expected entry 1 category 'when', got '#{trace[1].category}'" unless trace[1].category == "when"
    raise "Expected entry 2 category 'then', got '#{trace[2].category}'" unless trace[2].category == "then"
  end

  def trace_is_empty(state, **kw)
    trace = state[:trace]
    raise "Expected empty trace, got #{trace.length} entries" unless trace.empty?
  end
end

Aver.register(ActionTraceAdapter)

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

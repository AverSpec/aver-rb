require "spec_helper"

class AdapterDispatchDomain < Aver::Domain
  domain_name "adapter-dispatch"
  action :dispatch_action_through_proxy
  action :dispatch_query_returns_result
  action :dispatch_assertion_through_proxy
  action :dispatch_failing_assertion
  action :setup_multiple_adapters
  action :setup_parent_chain
  action :dispatch_typed_query
  assertion :action_trace_correct
  assertion :query_result_and_trace_correct
  assertion :assertion_trace_correct
  assertion :failing_assertion_trace_correct
  assertion :multiple_adapters_found
  assertion :parent_chain_lookup_works
  assertion :typed_query_result_correct
end

class AdapterDispatchAdapter < Aver::Adapter
  domain AdapterDispatchDomain
  protocol :unit, -> { {} }

  def dispatch_action_through_proxy(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "dispatch-action"
      action :submit_order
    end
    dd = d
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { { orders: [] } }
      define_method(:submit_order) { |ctx, **k| ctx[:orders] << k }
    end.new
    proto = Aver::UnitProtocol.new(-> { { orders: [] } }, name: "unit")
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.when.submit_order(id: "order-1")
    state[:trace] = ctx.trace
  end

  def dispatch_query_returns_result(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "dispatch-query"
      query :get_status, returns: String
    end
    dd = d
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:get_status) { |ctx| "active" }
    end.new
    proto = Aver::UnitProtocol.new(-> { {} }, name: "unit")
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    state[:query_result] = ctx.query.get_status
    state[:trace] = ctx.trace
  end

  def dispatch_assertion_through_proxy(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "dispatch-assert"
      assertion :is_valid
    end
    dd = d
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:is_valid) { |ctx| true }
    end.new
    proto = Aver::UnitProtocol.new(-> { {} }, name: "unit")
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.then.is_valid
    state[:trace] = ctx.trace
  end

  def dispatch_failing_assertion(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "dispatch-fail"
      assertion :must_pass
    end
    dd = d
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:must_pass) { |ctx| raise "nope" }
    end.new
    proto = Aver::UnitProtocol.new(-> { {} }, name: "unit")
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    begin
      ctx.then.must_pass
    rescue => e
      state[:error_message] = e.message
    end
    state[:trace] = ctx.trace
  end

  def setup_multiple_adapters(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "dispatch-multi"
      action :do_work
    end
    dd = d
    ac1 = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:do_work) { |ctx, **k| nil }
    end
    ac2 = Class.new(Aver::Adapter) do
      domain dd
      protocol :http, -> { {} }
      define_method(:do_work) { |ctx, **k| nil }
    end
    config = Aver::Configuration.new
    config.register(ac1)
    config.register(ac2)
    state[:found_adapters] = config.find_adapters(d)
  end

  def setup_parent_chain(state, **kw)
    parent = Class.new(Aver::Domain) do
      domain_name "parent-chain"
      action :base_op
    end
    child = parent.extend_domain("child-chain") do
      action :child_op
    end
    dd = parent
    ac = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:base_op) { |ctx, **k| nil }
    end
    config = Aver::Configuration.new
    config.register(ac)
    state[:found_adapters] = config.find_adapters(parent)
    state[:parent_adapter_class] = ac
    state[:child_domain] = child
    state[:parent_domain] = parent
  end

  def dispatch_typed_query(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "dispatch-typed"
      query :get_count, returns: Integer
    end
    dd = d
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:get_count) { |ctx| 42 }
    end.new
    proto = Aver::UnitProtocol.new(-> { {} }, name: "unit")
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    state[:query_result] = ctx.query.get_count
    state[:trace] = ctx.trace
  end

  def action_trace_correct(state, **kw)
    trace = state[:trace]
    raise "Expected 1 trace entry, got #{trace.length}" unless trace.length == 1
    raise "Expected kind 'action', got '#{trace[0].kind}'" unless trace[0].kind == "action"
    raise "Expected category 'when', got '#{trace[0].category}'" unless trace[0].category == "when"
    raise "Expected status 'pass', got '#{trace[0].status}'" unless trace[0].status == "pass"
  end

  def query_result_and_trace_correct(state, **kw)
    raise "Expected query result 'active', got '#{state[:query_result]}'" unless state[:query_result] == "active"
    trace = state[:trace]
    raise "Expected kind 'query', got '#{trace[0].kind}'" unless trace[0].kind == "query"
    raise "Expected status 'pass', got '#{trace[0].status}'" unless trace[0].status == "pass"
  end

  def assertion_trace_correct(state, **kw)
    trace = state[:trace]
    raise "Expected kind 'assertion', got '#{trace[0].kind}'" unless trace[0].kind == "assertion"
    raise "Expected status 'pass', got '#{trace[0].status}'" unless trace[0].status == "pass"
  end

  def failing_assertion_trace_correct(state, **kw)
    trace = state[:trace]
    raise "Expected 1 trace entry, got #{trace.length}" unless trace.length == 1
    raise "Expected status 'fail', got '#{trace[0].status}'" unless trace[0].status == "fail"
  end

  def multiple_adapters_found(state, **kw)
    found = state[:found_adapters]
    raise "Expected 2 adapters, got #{found.length}" unless found.length == 2
  end

  def parent_chain_lookup_works(state, **kw)
    found = state[:found_adapters]
    raise "Expected 1 adapter, got #{found.length}" unless found.length == 1
    raise "Expected parent adapter class" unless found[0].adapter_class.equal?(state[:parent_adapter_class])
    raise "Expected child parent to be parent domain" unless state[:child_domain].parent == state[:parent_domain]
  end

  def typed_query_result_correct(state, **kw)
    result = state[:query_result]
    raise "Expected 42, got #{result}" unless result == 42
    raise "Expected Integer, got #{result.class}" unless result.is_a?(Integer)
    trace = state[:trace]
    raise "Expected kind 'query', got '#{trace[0].kind}'" unless trace[0].kind == "query"
    raise "Expected status 'pass', got '#{trace[0].status}'" unless trace[0].status == "pass"
  end
end

Aver.register(AdapterDispatchAdapter)

RSpec.describe "Adapter dispatch acceptance", aver: AdapterDispatchDomain do

  aver_test "dispatches actions through proxy" do |ctx|
    ctx.when.dispatch_action_through_proxy
    ctx.then.action_trace_correct
  end

  aver_test "dispatches queries and returns results" do |ctx|
    ctx.when.dispatch_query_returns_result
    ctx.then.query_result_and_trace_correct
  end

  aver_test "dispatches assertions through proxy" do |ctx|
    ctx.when.dispatch_assertion_through_proxy
    ctx.then.assertion_trace_correct
  end

  aver_test "failing assertion with no prior trace" do |ctx|
    ctx.when.dispatch_failing_assertion
    ctx.then.failing_assertion_trace_correct
  end

  aver_test "multiple adapters registered for same domain" do |ctx|
    ctx.when.setup_multiple_adapters
    ctx.then.multiple_adapters_found
  end

  aver_test "parent chain lookup finds parent adapter" do |ctx|
    ctx.when.setup_parent_chain
    ctx.then.parent_chain_lookup_works
  end

  aver_test "query returns typed result value" do |ctx|
    ctx.when.dispatch_typed_query
    ctx.then.typed_query_result_correct
  end
end

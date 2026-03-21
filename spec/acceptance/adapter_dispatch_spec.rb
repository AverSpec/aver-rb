require "spec_helper"

AdapterDispatchDomain = Aver.domain("adapter-dispatch") do
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

AdapterDispatchAdapter = Aver.implement(AdapterDispatchDomain, protocol: Aver.unit { {} }) do
  handle(:dispatch_action_through_proxy) do |state, p|
    d = Aver.domain("dispatch-action") { action :submit_order }
    proto = Aver.unit { { orders: [] } }
    a = Aver.implement(d, protocol: proto) do
      handle(:submit_order) { |ctx, payload| ctx[:orders] << payload }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.when.submit_order(id: "order-1")
    state[:trace] = ctx.trace
  end

  handle(:dispatch_query_returns_result) do |state, p|
    d = Aver.domain("dispatch-query") { query :get_status, returns: String }
    proto = Aver.unit { {} }
    a = Aver.implement(d, protocol: proto) do
      handle(:get_status) { |ctx, payload| "active" }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    state[:query_result] = ctx.query.get_status
    state[:trace] = ctx.trace
  end

  handle(:dispatch_assertion_through_proxy) do |state, p|
    d = Aver.domain("dispatch-assert") { assertion :is_valid }
    proto = Aver.unit { {} }
    a = Aver.implement(d, protocol: proto) do
      handle(:is_valid) { |ctx, payload| true }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.then.is_valid
    state[:trace] = ctx.trace
  end

  handle(:dispatch_failing_assertion) do |state, p|
    d = Aver.domain("dispatch-fail") { assertion :must_pass }
    proto = Aver.unit { {} }
    a = Aver.implement(d, protocol: proto) do
      handle(:must_pass) { |ctx, payload| raise "nope" }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    begin
      ctx.then.must_pass
    rescue => e
      state[:error_message] = e.message
    end
    state[:trace] = ctx.trace
  end

  handle(:setup_multiple_adapters) do |state, p|
    d = Aver.domain("dispatch-multi") { action :do_work }
    p1 = Aver.unit(name: "unit") { {} }
    p2 = Aver.unit(name: "http") { {} }
    a1 = Aver.implement(d, protocol: p1) do
      handle(:do_work) { |ctx, payload| nil }
    end
    a2 = Aver.implement(d, protocol: p2) do
      handle(:do_work) { |ctx, payload| nil }
    end
    config = Aver::Configuration.new
    config.adapters << a1
    config.adapters << a2
    state[:found_adapters] = config.find_adapters(d)
  end

  handle(:setup_parent_chain) do |state, p|
    parent = Aver.domain("parent-chain") { action :base_op }
    child = parent.extend("child-chain") { action :child_op }
    proto = Aver.unit { {} }
    parent_adapter = Aver.implement(parent, protocol: proto) do
      handle(:base_op) { |ctx, payload| nil }
    end
    config = Aver::Configuration.new
    config.adapters << parent_adapter
    state[:found_adapters] = config.find_adapters(child)
    state[:parent_adapter] = parent_adapter
    state[:child_domain] = child
    state[:parent_domain] = parent
  end

  handle(:dispatch_typed_query) do |state, p|
    d = Aver.domain("dispatch-typed") { query :get_count, returns: Integer }
    proto = Aver.unit { {} }
    a = Aver.implement(d, protocol: proto) do
      handle(:get_count) { |ctx, payload| 42 }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    state[:query_result] = ctx.query.get_count
    state[:trace] = ctx.trace
  end

  handle(:action_trace_correct) do |state, p|
    trace = state[:trace]
    raise "Expected 1 trace entry, got #{trace.length}" unless trace.length == 1
    raise "Expected kind 'action', got '#{trace[0].kind}'" unless trace[0].kind == "action"
    raise "Expected category 'when', got '#{trace[0].category}'" unless trace[0].category == "when"
    raise "Expected status 'pass', got '#{trace[0].status}'" unless trace[0].status == "pass"
  end

  handle(:query_result_and_trace_correct) do |state, p|
    raise "Expected query result 'active', got '#{state[:query_result]}'" unless state[:query_result] == "active"
    trace = state[:trace]
    raise "Expected kind 'query', got '#{trace[0].kind}'" unless trace[0].kind == "query"
    raise "Expected status 'pass', got '#{trace[0].status}'" unless trace[0].status == "pass"
  end

  handle(:assertion_trace_correct) do |state, p|
    trace = state[:trace]
    raise "Expected kind 'assertion', got '#{trace[0].kind}'" unless trace[0].kind == "assertion"
    raise "Expected status 'pass', got '#{trace[0].status}'" unless trace[0].status == "pass"
  end

  handle(:failing_assertion_trace_correct) do |state, p|
    trace = state[:trace]
    raise "Expected 1 trace entry, got #{trace.length}" unless trace.length == 1
    raise "Expected status 'fail', got '#{trace[0].status}'" unless trace[0].status == "fail"
  end

  handle(:multiple_adapters_found) do |state, p|
    found = state[:found_adapters]
    raise "Expected 2 adapters, got #{found.length}" unless found.length == 2
  end

  handle(:parent_chain_lookup_works) do |state, p|
    found = state[:found_adapters]
    raise "Expected 1 adapter, got #{found.length}" unless found.length == 1
    raise "Expected parent adapter" unless found[0].equal?(state[:parent_adapter])
    raise "Expected child parent to be parent domain" unless state[:child_domain].parent == state[:parent_domain]
  end

  handle(:typed_query_result_correct) do |state, p|
    result = state[:query_result]
    raise "Expected 42, got #{result}" unless result == 42
    raise "Expected Integer, got #{result.class}" unless result.is_a?(Integer)
    trace = state[:trace]
    raise "Expected kind 'query', got '#{trace[0].kind}'" unless trace[0].kind == "query"
    raise "Expected status 'pass', got '#{trace[0].status}'" unless trace[0].status == "pass"
  end
end

Aver.configuration.adapters << AdapterDispatchAdapter

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

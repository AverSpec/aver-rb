require "spec_helper"

# Domain that tests the Aver framework itself
AverCore = Aver.domain("aver-core") do
  action :create_domain
  action :create_adapter
  action :register_adapter
  action :dispatch_action
  action :dispatch_query
  action :dispatch_assertion
  action :dispatch_via_given
  query :get_trace, returns: Array
  query :get_coverage, returns: Hash
  assertion :domain_has_markers
  assertion :proxy_blocks_wrong_kind
  assertion :adapter_rejects_missing_handlers
  assertion :adapter_rejects_extra_handlers
  assertion :trace_records_failure
  assertion :domain_extension_inherits
  assertion :composed_suite_works
  assertion :trace_format_works
  assertion :config_snapshot_restore
end

AverCoreAdapter = Aver.implement(AverCore, protocol: Aver.unit { {} }) do
  handle(:create_domain) do |state, p|
    state[:domain] = Aver.domain(p[:name]) do
      action :go
      query :peek, returns: Hash
      assertion :check
    end
  end

  handle(:create_adapter) do |state, p|
    d = state[:domain]
    state[:adapter] = Aver.implement(d, protocol: Aver.unit { [] }) do
      handle(:go) { |ctx, payload| ctx << (payload || "done") }
      handle(:peek) { |ctx, payload| { items: ctx.length } }
      handle(:check) { |ctx, payload| expect(ctx).not_to be_empty }
    end
  end

  handle(:register_adapter) do |state, p|
    Aver.configuration.adapters << state[:adapter]
  end

  handle(:dispatch_action) do |state, p|
    d = state[:domain]
    a = state[:adapter]
    proto_ctx = a.protocol.setup
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto_ctx)
    ctx.when.go(title: "test")
    state[:ctx] = ctx
    state[:proto_ctx] = proto_ctx
  end

  handle(:dispatch_query) do |state, p|
    ctx = state[:ctx]
    result = ctx.query.peek
    state[:query_result] = result
  end

  handle(:dispatch_assertion) do |state, p|
    ctx = state[:ctx]
    ctx.then.check
  end

  handle(:dispatch_via_given) do |state, p|
    d = state[:domain]
    a = state[:adapter]
    proto_ctx = a.protocol.setup
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto_ctx)
    ctx.given.go
    ctx.given.check
    state[:given_ctx] = ctx
  end

  handle(:get_trace) do |state, p|
    ctx = state[:ctx] || state[:given_ctx]
    ctx.trace
  end

  handle(:get_coverage) do |state, p|
    ctx = state[:ctx]
    ctx.get_coverage
  end

  handle(:domain_has_markers) do |state, p|
    d = state[:domain]
    expect(d.markers.keys).to contain_exactly(:go, :peek, :check)
  end

  handle(:proxy_blocks_wrong_kind) do |state, p|
    d = state[:domain]
    a = state[:adapter]
    proto_ctx = a.protocol.setup
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto_ctx)
    expect { ctx.then.go }.to raise_error(TypeError)
    expect { ctx.query.go }.to raise_error(TypeError)
  end

  handle(:adapter_rejects_missing_handlers) do |state, p|
    d = state[:domain]
    expect {
      Aver.implement(d, protocol: Aver.unit { nil }) do
        handle(:go) { |ctx, p| }
      end
    }.to raise_error(Aver::AdapterError, /Missing/)
  end

  handle(:adapter_rejects_extra_handlers) do |state, p|
    d = state[:domain]
    expect {
      Aver.implement(d, protocol: Aver.unit { nil }) do
        handle(:go) { |ctx, p| }
        handle(:peek) { |ctx, p| }
        handle(:check) { |ctx, p| }
        handle(:bogus) { |ctx, p| }
      end
    }.to raise_error(Aver::AdapterError, /Extra/)
  end

  handle(:trace_records_failure) do |state, p|
    d = Aver.domain("fail-test") { action :boom }
    a = Aver.implement(d, protocol: Aver.unit { nil }) do
      handle(:boom) { |ctx, payload| raise "kaboom" }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: nil)
    begin
      ctx.when.boom
    rescue
    end
    expect(ctx.trace[0].status).to eq("fail")
    expect(ctx.trace[0].error).to eq("kaboom")
  end

  handle(:domain_extension_inherits) do |state, p|
    parent = Aver.domain("base") { action :login }
    child = parent.extend("child") { action :logout }
    expect(child.markers.keys).to contain_exactly(:login, :logout)
    expect(child.parent).to eq(parent)
  end

  handle(:composed_suite_works) do |state, p|
    d1 = Aver.domain("d1") { action :a1 }
    d2 = Aver.domain("d2") { action :a2 }
    a1 = Aver.implement(d1, protocol: Aver.unit { [] }) { handle(:a1) { |ctx, pl| ctx << "a1" } }
    a2 = Aver.implement(d2, protocol: Aver.unit { [] }) { handle(:a2) { |ctx, pl| ctx << "a2" } }
    Aver.composed_suite(first: [d1, a1], second: [d2, a2]) do |ctx|
      ctx.first.when.a1
      ctx.second.when.a2
      expect(ctx.trace.length).to eq(2)
    end
  end

  handle(:trace_format_works) do |state, p|
    entry = Aver::TraceEntry.new(kind: "action", category: "when", name: "t.op", status: "pass", duration_ms: 5.0)
    output = Aver.format_trace([entry])
    expect(output).to include("[PASS]")
    expect(output).to include("WHEN")
  end

  handle(:config_snapshot_restore) do |state, p|
    config = Aver::Configuration.new
    config.teardown_failure_mode = :warn
    snap = config.snapshot
    config.reset!
    expect(config.teardown_failure_mode).to eq(:fail)
    config.restore(snap)
    expect(config.teardown_failure_mode).to eq(:warn)
  end
end

RSpec.describe "Aver Core (dogfooding)", aver: AverCore do
  before(:all) do
    Aver.configuration.reset!
    Aver.configuration.adapters << AverCoreAdapter
  end

  aver_test "create a domain with markers" do |ctx|
    ctx.when.create_domain(name: "test-domain")
    ctx.then.domain_has_markers
  end

  aver_test "dispatch action through proxy" do |ctx|
    ctx.given.create_domain(name: "dispatch-test")
    ctx.given.create_adapter
    ctx.when.dispatch_action
    trace = ctx.query.get_trace
    expect(trace.length).to eq(1)
    expect(trace[0].status).to eq("pass")
  end

  aver_test "dispatch query returns value" do |ctx|
    ctx.given.create_domain(name: "query-test")
    ctx.given.create_adapter
    ctx.given.dispatch_action
    ctx.when.dispatch_query
  end

  aver_test "dispatch assertion" do |ctx|
    ctx.given.create_domain(name: "assert-test")
    ctx.given.create_adapter
    ctx.given.dispatch_action
    ctx.when.dispatch_assertion
  end

  aver_test "given allows actions and assertions" do |ctx|
    ctx.given.create_domain(name: "given-test")
    ctx.given.create_adapter
    ctx.when.dispatch_via_given
    trace = ctx.query.get_trace
    expect(trace.length).to eq(2)
  end

  aver_test "proxy blocks wrong kind" do |ctx|
    ctx.given.create_domain(name: "block-test")
    ctx.given.create_adapter
    ctx.then.proxy_blocks_wrong_kind
  end

  aver_test "adapter rejects missing handlers" do |ctx|
    ctx.given.create_domain(name: "missing-test")
    ctx.then.adapter_rejects_missing_handlers
  end

  aver_test "adapter rejects extra handlers" do |ctx|
    ctx.given.create_domain(name: "extra-test")
    ctx.then.adapter_rejects_extra_handlers
  end

  aver_test "trace records failure" do |ctx|
    ctx.then.trace_records_failure
  end

  aver_test "domain extension inherits markers" do |ctx|
    ctx.then.domain_extension_inherits
  end

  aver_test "coverage tracking" do |ctx|
    ctx.given.create_domain(name: "cov-test")
    ctx.given.create_adapter
    ctx.given.dispatch_action
    coverage = ctx.query.get_coverage
    expect(coverage[:percentage]).to be > 0
  end

  aver_test "composed suite dispatches across namespaces" do |ctx|
    ctx.then.composed_suite_works
  end

  aver_test "trace formatting" do |ctx|
    ctx.then.trace_format_works
  end

  aver_test "config snapshot and restore" do |ctx|
    ctx.then.config_snapshot_restore
  end
end

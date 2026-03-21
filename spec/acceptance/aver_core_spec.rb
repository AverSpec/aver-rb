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
  query :get_trace_length, returns: Integer
  query :get_coverage, returns: Hash
  query :get_coverage_percentage, returns: Integer
  assertion :domain_has_markers
  assertion :proxy_blocks_wrong_kind
  assertion :adapter_rejects_missing_handlers
  assertion :adapter_rejects_extra_handlers
  assertion :trace_records_failure
  assertion :domain_extension_inherits
  assertion :composed_suite_works
  assertion :trace_format_works
  assertion :config_snapshot_restore
  assertion :trace_has_length
  assertion :trace_entry_passed
  assertion :coverage_above_zero
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
      handle(:check) { |ctx, payload| raise "context is empty" if ctx.empty? }
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

  handle(:get_trace_length) do |state, p|
    ctx = state[:ctx] || state[:given_ctx]
    ctx.trace.length
  end

  handle(:get_coverage) do |state, p|
    ctx = state[:ctx]
    ctx.get_coverage
  end

  handle(:get_coverage_percentage) do |state, p|
    ctx = state[:ctx]
    ctx.get_coverage[:percentage]
  end

  handle(:domain_has_markers) do |state, p|
    d = state[:domain]
    keys = d.markers.keys
    unless keys.sort == [:check, :go, :peek]
      raise "Expected markers [:check, :go, :peek], got #{keys.sort.inspect}"
    end
  end

  handle(:proxy_blocks_wrong_kind) do |state, p|
    d = state[:domain]
    a = state[:adapter]
    proto_ctx = a.protocol.setup
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto_ctx)
    begin
      ctx.then.go
      raise "Expected TypeError for ctx.then.go but none raised"
    rescue TypeError
      # expected
    end
    begin
      ctx.query.go
      raise "Expected TypeError for ctx.query.go but none raised"
    rescue TypeError
      # expected
    end
  end

  handle(:adapter_rejects_missing_handlers) do |state, p|
    d = state[:domain]
    begin
      Aver.implement(d, protocol: Aver.unit { nil }) do
        handle(:go) { |ctx, p| }
      end
      raise "Expected AdapterError for missing handlers but none raised"
    rescue Aver::AdapterError => e
      raise "Expected /Missing/ in error, got: #{e.message}" unless e.message.match?(/Missing/)
    end
  end

  handle(:adapter_rejects_extra_handlers) do |state, p|
    d = state[:domain]
    begin
      Aver.implement(d, protocol: Aver.unit { nil }) do
        handle(:go) { |ctx, p| }
        handle(:peek) { |ctx, p| }
        handle(:check) { |ctx, p| }
        handle(:bogus) { |ctx, p| }
      end
      raise "Expected AdapterError for extra handlers but none raised"
    rescue Aver::AdapterError => e
      raise "Expected /Extra/ in error, got: #{e.message}" unless e.message.match?(/Extra/)
    end
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
    raise "Expected fail status, got #{ctx.trace[0].status}" unless ctx.trace[0].status == "fail"
    raise "Expected 'kaboom' error, got #{ctx.trace[0].error}" unless ctx.trace[0].error == "kaboom"
  end

  handle(:domain_extension_inherits) do |state, p|
    parent = Aver.domain("base") { action :login }
    child = parent.extend("child") { action :logout }
    unless child.markers.keys.sort == [:login, :logout]
      raise "Expected [:login, :logout], got #{child.markers.keys.sort.inspect}"
    end
    raise "Expected parent to be base domain" unless child.parent == parent
  end

  handle(:composed_suite_works) do |state, p|
    d1 = Aver.domain("d1") { action :a1 }
    d2 = Aver.domain("d2") { action :a2 }
    a1 = Aver.implement(d1, protocol: Aver.unit { [] }) { handle(:a1) { |ctx, pl| ctx << "a1" } }
    a2 = Aver.implement(d2, protocol: Aver.unit { [] }) { handle(:a2) { |ctx, pl| ctx << "a2" } }
    Aver.composed_suite(first: [d1, a1], second: [d2, a2]) do |ctx|
      ctx.first.when.a1
      ctx.second.when.a2
      raise "Expected 2 trace entries, got #{ctx.trace.length}" unless ctx.trace.length == 2
    end
  end

  handle(:trace_format_works) do |state, p|
    entry = Aver::TraceEntry.new(kind: "action", category: "when", name: "t.op", status: "pass", duration_ms: 5.0)
    output = Aver.format_trace([entry])
    raise "Expected [PASS] in output" unless output.include?("[PASS]")
    raise "Expected WHEN in output" unless output.include?("WHEN")
  end

  handle(:config_snapshot_restore) do |state, p|
    config = Aver::Configuration.new
    config.teardown_failure_mode = :warn
    snap = config.snapshot
    config.reset!
    raise "Expected :fail after reset, got #{config.teardown_failure_mode}" unless config.teardown_failure_mode == :fail
    config.restore(snap)
    raise "Expected :warn after restore, got #{config.teardown_failure_mode}" unless config.teardown_failure_mode == :warn
  end

  handle(:trace_has_length) do |state, p|
    ctx = state[:ctx] || state[:given_ctx]
    expected = p[:expected]
    actual = ctx.trace.length
    raise "Expected trace length #{expected}, got #{actual}" unless actual == expected
  end

  handle(:trace_entry_passed) do |state, p|
    ctx = state[:ctx] || state[:given_ctx]
    index = p[:index]
    entry = ctx.trace[index]
    raise "No trace entry at index #{index}" unless entry
    raise "Expected pass at index #{index}, got #{entry.status}" unless entry.status == "pass"
  end

  handle(:coverage_above_zero) do |state, p|
    ctx = state[:ctx]
    cov = ctx.get_coverage
    raise "Expected coverage > 0, got #{cov[:percentage]}" unless cov[:percentage] > 0
  end
end

Aver.configuration.reset!
Aver.configuration.adapters << AverCoreAdapter

RSpec.describe "Aver Core (dogfooding)", aver: AverCore do

  aver_test "create a domain with markers" do |ctx|
    ctx.when.create_domain(name: "test-domain")
    ctx.then.domain_has_markers
  end

  aver_test "dispatch action through proxy" do |ctx|
    ctx.given.create_domain(name: "dispatch-test")
    ctx.given.create_adapter
    ctx.when.dispatch_action
    ctx.then.trace_has_length(expected: 1)
    ctx.then.trace_entry_passed(index: 0)
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
    ctx.then.trace_has_length(expected: 2)
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
    ctx.then.coverage_above_zero
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

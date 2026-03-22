require "spec_helper"

class AverCoreDomain < Aver::Domain
  domain_name "aver-core"
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

class AverCoreAdapter < Aver::Adapter
  domain AverCoreDomain
  protocol :unit, -> { {} }

  def create_domain(state, **p)
    state[:domain] = Class.new(Aver::Domain) do
      domain_name p[:name]
      action :go
      query :peek, returns: Hash
      assertion :check
    end
  end

  def create_adapter(state, **p)
    d = state[:domain]
    dd = d
    klass = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { [] }
      define_method(:go) { |ctx, **kw| ctx << (kw.empty? ? "done" : kw) }
      define_method(:peek) { |ctx| { items: ctx.length } }
      define_method(:check) { |ctx| raise "context is empty" if ctx.empty? }
    end
    state[:adapter] = klass.new
    state[:adapter_proto] = Aver::UnitProtocol.new(-> { [] }, name: "unit")
  end

  def register_adapter(state, **p)
    # No-op in the OO world since we don't use config for inline adapters
  end

  def dispatch_action(state, **p)
    d = state[:domain]
    a = state[:adapter]
    proto = state[:adapter_proto]
    proto_ctx = proto.setup
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto_ctx)
    ctx.when.go(title: "test")
    state[:ctx] = ctx
    state[:proto_ctx] = proto_ctx
  end

  def dispatch_query(state, **p)
    ctx = state[:ctx]
    result = ctx.query.peek
    state[:query_result] = result
  end

  def dispatch_assertion(state, **p)
    ctx = state[:ctx]
    ctx.then.check
  end

  def dispatch_via_given(state, **p)
    d = state[:domain]
    a = state[:adapter]
    proto = state[:adapter_proto]
    proto_ctx = proto.setup
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto_ctx)
    ctx.given.go
    ctx.given.check
    state[:given_ctx] = ctx
  end

  def get_trace(state, **p)
    ctx = state[:ctx] || state[:given_ctx]
    ctx.trace
  end

  def get_trace_length(state, **p)
    ctx = state[:ctx] || state[:given_ctx]
    ctx.trace.length
  end

  def get_coverage(state, **p)
    ctx = state[:ctx]
    ctx.get_coverage
  end

  def get_coverage_percentage(state, **p)
    ctx = state[:ctx]
    ctx.get_coverage[:percentage]
  end

  def domain_has_markers(state, **p)
    d = state[:domain]
    keys = d.markers.keys
    unless keys.sort == [:check, :go, :peek]
      raise "Expected markers [:check, :go, :peek], got #{keys.sort.inspect}"
    end
  end

  def proxy_blocks_wrong_kind(state, **p)
    d = state[:domain]
    a = state[:adapter]
    proto = state[:adapter_proto]
    proto_ctx = proto.setup
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

  def adapter_rejects_missing_handlers(state, **p)
    d = state[:domain]
    dd = d
    begin
      klass = Class.new(Aver::Adapter) do
        domain dd
        protocol :unit, -> { nil }
        define_method(:go) { |ctx, **k| }
      end
      klass.validate!
      raise "Expected AdapterError for missing handlers but none raised"
    rescue Aver::AdapterError => e
      raise "Expected /Missing/ in error, got: #{e.message}" unless e.message.match?(/Missing/)
    end
  end

  def adapter_rejects_extra_handlers(state, **p)
    d = state[:domain]
    dd = d
    begin
      klass = Class.new(Aver::Adapter) do
        domain dd
        protocol :unit, -> { nil }
        define_method(:go) { |ctx, **k| }
        define_method(:peek) { |ctx, **k| }
        define_method(:check) { |ctx, **k| }
        define_method(:bogus) { |ctx, **k| }
      end
      klass.validate!
      raise "Expected AdapterError for extra handlers but none raised"
    rescue Aver::AdapterError => e
      raise "Expected /Extra/ in error, got: #{e.message}" unless e.message.match?(/Extra/)
    end
  end

  def trace_records_failure(state, **p)
    d = Class.new(Aver::Domain) do
      domain_name "fail-test"
      action :boom
    end
    dd = d
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { nil }
      define_method(:boom) { |ctx, **kw| raise "kaboom" }
    end.new
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: nil)
    begin
      ctx.when.boom
    rescue
    end
    raise "Expected fail status, got #{ctx.trace[0].status}" unless ctx.trace[0].status == "fail"
    raise "Expected 'kaboom' error, got #{ctx.trace[0].error}" unless ctx.trace[0].error == "kaboom"
  end

  def domain_extension_inherits(state, **p)
    parent = Class.new(Aver::Domain) do
      domain_name "base"
      action :login
    end
    child = parent.extend_domain("child") { action :logout }
    unless child.markers.keys.sort == [:login, :logout]
      raise "Expected [:login, :logout], got #{child.markers.keys.sort.inspect}"
    end
    raise "Expected parent to be base domain" unless child.parent == parent
  end

  def composed_suite_works(state, **p)
    d1 = Class.new(Aver::Domain) do
      domain_name "d1"
      action :a1
    end
    d2 = Class.new(Aver::Domain) do
      domain_name "d2"
      action :a2
    end
    dd1 = d1
    dd2 = d2
    proto1 = Aver.unit { [] }
    proto2 = Aver.unit { [] }
    a1 = Class.new(Aver::Adapter) do
      domain dd1
      protocol :unit, -> { [] }
      define_method(:a1) { |ctx, **kw| ctx << "a1" }
    end.new
    a1.define_singleton_method(:protocol) { proto1 }
    a2 = Class.new(Aver::Adapter) do
      domain dd2
      protocol :unit, -> { [] }
      define_method(:a2) { |ctx, **kw| ctx << "a2" }
    end.new
    a2.define_singleton_method(:protocol) { proto2 }
    Aver.composed_suite(first: [d1, a1], second: [d2, a2]) do |ctx|
      ctx.first.when.a1
      ctx.second.when.a2
      raise "Expected 2 trace entries, got #{ctx.trace.length}" unless ctx.trace.length == 2
    end
  end

  def trace_format_works(state, **p)
    entry = Aver::TraceEntry.new(kind: "action", category: "when", name: "t.op", status: "pass", duration_ms: 5.0)
    output = Aver.format_trace([entry])
    raise "Expected [PASS] in output" unless output.include?("[PASS]")
    raise "Expected WHEN in output" unless output.include?("WHEN")
  end

  def config_snapshot_restore(state, **p)
    config = Aver::Configuration.new
    config.teardown_failure_mode = :warn
    snap = config.snapshot
    config.reset!
    raise "Expected :fail after reset, got #{config.teardown_failure_mode}" unless config.teardown_failure_mode == :fail
    config.restore(snap)
    raise "Expected :warn after restore, got #{config.teardown_failure_mode}" unless config.teardown_failure_mode == :warn
  end

  def trace_has_length(state, **p)
    ctx = state[:ctx] || state[:given_ctx]
    expected = p[:expected]
    actual = ctx.trace.length
    raise "Expected trace length #{expected}, got #{actual}" unless actual == expected
  end

  def trace_entry_passed(state, **p)
    ctx = state[:ctx] || state[:given_ctx]
    index = p[:index]
    entry = ctx.trace[index]
    raise "No trace entry at index #{index}" unless entry
    raise "Expected pass at index #{index}, got #{entry.status}" unless entry.status == "pass"
  end

  def coverage_above_zero(state, **p)
    ctx = state[:ctx]
    cov = ctx.get_coverage
    raise "Expected coverage > 0, got #{cov[:percentage]}" unless cov[:percentage] > 0
  end
end

Aver.register(AverCoreAdapter)

RSpec.describe "Aver Core (dogfooding)", aver: AverCoreDomain do

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

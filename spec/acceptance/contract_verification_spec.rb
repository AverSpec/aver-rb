require "spec_helper"

class ContractVerificationDomain < Aver::Domain
  domain_name "contract-verification"
  action :extract_static_contract
  action :extract_parameterized_contract
  action :verify_matching_traces
  action :verify_missing_span
  action :verify_literal_mismatch
  action :verify_correlation_violation
  action :verify_no_matching_traces
  action :round_trip_contract
  assertion :static_contract_correct
  assertion :parameterized_contract_correct
  assertion :matching_traces_pass
  assertion :missing_span_detected
  assertion :literal_mismatch_detected
  assertion :correlation_violation_detected
  assertion :no_matching_traces_detected
  assertion :round_trip_passes
end

class ContractVerificationAdapter < Aver::Adapter
  domain ContractVerificationDomain
  protocol :unit, -> { {} }

  private

  def _build_domain_with_telemetry(name, markers_spec)
    Class.new(Aver::Domain) do
      domain_name name
      markers_spec.each do |m|
        action m[:name], telemetry: Aver::TelemetryExpectation.new(
          span: m[:span],
          attributes: m.fetch(:attributes, {})
        )
      end
    end
  end

  def _stub_collector(spans)
    collected = spans.map do |s|
      Aver::CollectedSpan.new(
        trace_id: s.fetch(:trace_id, "t0"),
        span_id: s.fetch(:span_id, "s0"),
        name: s[:name],
        attributes: s.fetch(:attributes, {}),
        parent_span_id: s.fetch(:parent_span_id, nil)
      )
    end
    collector = Object.new
    collector.define_singleton_method(:get_spans) { collected }
    collector.define_singleton_method(:reset) { nil }
    collector
  end

  def _build_protocol_with_collector(collector)
    proto = Aver::Protocol.new(name: "cv-test")
    proto.define_singleton_method(:setup) { {} }
    proto.define_singleton_method(:teardown) { |ctx| nil }
    proto.telemetry = collector
    proto
  end

  def _build_adapter_for_domain(d, proto)
    dd = d
    klass = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
    end
    d.markers.each_key do |marker_name|
      klass.define_method(marker_name) { |ctx, **k| "done" }
    end
    klass.new
  end

  def _run_operations(domain, adapter, protocol)
    ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: protocol.setup, protocol: protocol)
    domain.markers.each_key do |marker_name|
      ctx.when.send(marker_name)
    end
    ctx
  end

  def _extract_results(ctx, test_name: "cv-test")
    [{ test_name: test_name, trace: ctx.trace }]
  end

  def _make_production_traces(spans_per_trace)
    spans_per_trace.map.with_index do |spans, i|
      trace_id = spans.first&.fetch(:trace_id, "pt#{i}") || "pt#{i}"
      prod_spans = spans.map do |s|
        Aver::ProductionSpan.new(
          name: s[:name],
          attributes: s.fetch(:attributes, {}),
          span_id: s.fetch(:span_id, nil),
          parent_span_id: s.fetch(:parent_span_id, nil)
        )
      end
      Aver::ProductionTrace.new(trace_id: trace_id, spans: prod_spans)
    end
  end

  public

  def extract_static_contract(state, **kw)
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = _build_domain_with_telemetry("cv-static", [
      { name: :login, span: "auth.login", attributes: { "user.role" => "admin" } },
    ])
    collector = _stub_collector([
      { name: "auth.login", attributes: { "user.role" => "admin" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = _build_protocol_with_collector(collector)
    a = _build_adapter_for_domain(d, proto)
    ctx = _run_operations(d, a, proto)
    state[:contract] = Aver.extract_contract(d, _extract_results(ctx))
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  def extract_parameterized_contract(state, **kw)
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = _build_domain_with_telemetry("cv-param", [
      { name: :signup, span: "user.signup", attributes: { "user.email" => "alice@test.com" } },
    ])
    collector = _stub_collector([
      { name: "user.signup", attributes: { "user.email" => "alice@test.com" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = _build_protocol_with_collector(collector)
    a = _build_adapter_for_domain(d, proto)
    ctx = _run_operations(d, a, proto)
    state[:contract] = Aver.extract_contract(d, _extract_results(ctx))
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  def verify_matching_traces(state, **kw)
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = _build_domain_with_telemetry("cv-match", [
      { name: :checkout, span: "order.checkout", attributes: { "amount" => "100" } },
    ])
    collector = _stub_collector([
      { name: "order.checkout", attributes: { "amount" => "100" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = _build_protocol_with_collector(collector)
    a = _build_adapter_for_domain(d, proto)
    ctx = _run_operations(d, a, proto)
    contract = Aver.extract_contract(d, _extract_results(ctx))
    prod_traces = _make_production_traces([
      [{ name: "order.checkout", attributes: { "amount" => "100" }, trace_id: "t1", span_id: "s1" }],
    ])
    state[:report] = Aver.verify_contract(contract, prod_traces)
    state[:domain_name] = "cv-match"
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  def verify_missing_span(state, **kw)
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = _build_domain_with_telemetry("cv-missing", [
      { name: :start, span: "checkout.start" },
      { name: :charge, span: "payment.charge" },
    ])
    collector = _stub_collector([
      { name: "checkout.start", trace_id: "t1", span_id: "s1" },
      { name: "payment.charge", trace_id: "t1", span_id: "s2" },
    ])
    proto = _build_protocol_with_collector(collector)
    a = _build_adapter_for_domain(d, proto)
    ctx = _run_operations(d, a, proto)
    contract = Aver.extract_contract(d, _extract_results(ctx))
    prod_traces = _make_production_traces([
      [{ name: "checkout.start", trace_id: "t1", span_id: "s1" }],
    ])
    state[:report] = Aver.verify_contract(contract, prod_traces)
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  def verify_literal_mismatch(state, **kw)
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = _build_domain_with_telemetry("cv-literal", [
      { name: :cancel, span: "order.cancel", attributes: { "order.status" => "cancelled" } },
    ])
    collector = _stub_collector([
      { name: "order.cancel", attributes: { "order.status" => "cancelled" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = _build_protocol_with_collector(collector)
    a = _build_adapter_for_domain(d, proto)
    ctx = _run_operations(d, a, proto)
    contract = Aver.extract_contract(d, _extract_results(ctx))
    prod_traces = _make_production_traces([
      [{ name: "order.cancel", attributes: { "order.status" => "canceled" }, trace_id: "t1", span_id: "s1" }],
    ])
    state[:report] = Aver.verify_contract(contract, prod_traces)
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  def verify_correlation_violation(state, **kw)
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = _build_domain_with_telemetry("cv-corr", [
      { name: :login, span: "auth.login", attributes: { "user.email" => "alice@co.com" } },
      { name: :session, span: "auth.session", attributes: { "user.email" => "alice@co.com" } },
    ])
    collector = _stub_collector([
      { name: "auth.login", attributes: { "user.email" => "alice@co.com" }, trace_id: "t1", span_id: "s1" },
      { name: "auth.session", attributes: { "user.email" => "alice@co.com" }, trace_id: "t1", span_id: "s2" },
    ])
    proto = _build_protocol_with_collector(collector)
    a = _build_adapter_for_domain(d, proto)
    ctx = _run_operations(d, a, proto)
    contract = Aver.extract_contract(d, _extract_results(ctx))
    contract.entries[0].spans.each do |span_exp|
      span_exp.attributes.each do |key, binding|
        binding.kind = "correlated"
        binding.symbol = :email
      end
    end
    prod_traces = _make_production_traces([
      [
        { name: "auth.login", attributes: { "user.email" => "alice@co.com" }, trace_id: "t1", span_id: "s1" },
        { name: "auth.session", attributes: { "user.email" => "bob@co.com" }, trace_id: "t1", span_id: "s2" },
      ],
    ])
    state[:report] = Aver.verify_contract(contract, prod_traces)
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  def verify_no_matching_traces(state, **kw)
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = _build_domain_with_telemetry("cv-no-match", [
      { name: :expected_op, span: "expected.span" },
    ])
    collector = _stub_collector([
      { name: "expected.span", trace_id: "t1", span_id: "s1" },
    ])
    proto = _build_protocol_with_collector(collector)
    a = _build_adapter_for_domain(d, proto)
    ctx = _run_operations(d, a, proto)
    contract = Aver.extract_contract(d, _extract_results(ctx))
    prod_traces = _make_production_traces([
      [{ name: "unrelated.span", trace_id: "t1", span_id: "s1" }],
    ])
    state[:report] = Aver.verify_contract(contract, prod_traces)
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  def round_trip_contract(state, **kw)
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = _build_domain_with_telemetry("cv-roundtrip", [
      { name: :op_one, span: "service.op_one", attributes: { "key" => "value" } },
    ])
    collector = _stub_collector([
      { name: "service.op_one", attributes: { "key" => "value" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = _build_protocol_with_collector(collector)
    a = _build_adapter_for_domain(d, proto)
    ctx = _run_operations(d, a, proto)
    contract = Aver.extract_contract(d, _extract_results(ctx))

    hash = {
      domain: contract.domain,
      entries: contract.entries.map do |entry|
        {
          test_name: entry.test_name,
          spans: entry.spans.map do |s|
            {
              name: s.name,
              attributes: s.attributes.transform_values { |b| { kind: b.kind, value: b.value } },
              parent_name: s.parent_name,
            }
          end,
        }
      end,
    }

    rebuilt_entries = hash[:entries].map do |e|
      spans = e[:spans].map do |s|
        attrs = s[:attributes].transform_values { |a| Aver::AttributeBinding.new(kind: a[:kind], value: a[:value]) }
        Aver::SpanExpectation.new(name: s[:name], attributes: attrs, parent_name: s[:parent_name])
      end
      Aver::ContractEntry.new(test_name: e[:test_name], spans: spans)
    end
    rebuilt = Aver::BehavioralContract.new(domain: hash[:domain], entries: rebuilt_entries)

    prod_traces = _make_production_traces([
      [{ name: "service.op_one", attributes: { "key" => "value" }, trace_id: "t1", span_id: "s1" }],
    ])
    state[:report] = Aver.verify_contract(rebuilt, prod_traces)
    state[:domain_name] = "cv-roundtrip"
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  def static_contract_correct(state, **kw)
    contract = state[:contract]
    raise "Expected domain 'cv-static', got '#{contract.domain}'" unless contract.domain == "cv-static"
    raise "Expected 1 entry, got #{contract.entries.length}" unless contract.entries.length == 1
    raise "Expected 1 span, got #{contract.entries[0].spans.length}" unless contract.entries[0].spans.length == 1
    raise "Expected span 'auth.login', got '#{contract.entries[0].spans[0].name}'" unless contract.entries[0].spans[0].name == "auth.login"
  end

  def parameterized_contract_correct(state, **kw)
    contract = state[:contract]
    raise "Expected 1 entry, got #{contract.entries.length}" unless contract.entries.length == 1
    span_exp = contract.entries[0].spans[0]
    raise "Expected span 'user.signup', got '#{span_exp.name}'" unless span_exp.name == "user.signup"
    raise "Expected literal kind, got '#{span_exp.attributes["user.email"].kind}'" unless span_exp.attributes["user.email"].kind == "literal"
    raise "Expected value 'alice@test.com', got '#{span_exp.attributes["user.email"].value}'" unless span_exp.attributes["user.email"].value == "alice@test.com"
  end

  def matching_traces_pass(state, **kw)
    report = state[:report]
    raise "Expected 0 violations, got #{report.total_violations}" unless report.total_violations == 0
    raise "Expected domain 'cv-match', got '#{report.domain}'" unless report.domain == state[:domain_name]
  end

  def missing_span_detected(state, **kw)
    report = state[:report]
    raise "Expected violations > 0, got #{report.total_violations}" unless report.total_violations > 0
    kinds = report.results.flat_map { |r| r.violations.map(&:kind) }
    raise "Expected 'missing-span' violation, got #{kinds.inspect}" unless kinds.include?("missing-span")
  end

  def literal_mismatch_detected(state, **kw)
    report = state[:report]
    raise "Expected violations > 0, got #{report.total_violations}" unless report.total_violations > 0
    kinds = report.results.flat_map { |r| r.violations.map(&:kind) }
    raise "Expected 'literal-mismatch' violation, got #{kinds.inspect}" unless kinds.include?("literal-mismatch")
  end

  def correlation_violation_detected(state, **kw)
    report = state[:report]
    raise "Expected violations > 0, got #{report.total_violations}" unless report.total_violations > 0
    kinds = report.results.flat_map { |r| r.violations.map(&:kind) }
    raise "Expected 'correlation-violation', got #{kinds.inspect}" unless kinds.include?("correlation-violation")
  end

  def no_matching_traces_detected(state, **kw)
    report = state[:report]
    raise "Expected violations > 0, got #{report.total_violations}" unless report.total_violations > 0
    kinds = report.results.flat_map { |r| r.violations.map(&:kind) }
    raise "Expected 'no-matching-traces', got #{kinds.inspect}" unless kinds.include?("no-matching-traces")
  end

  def round_trip_passes(state, **kw)
    report = state[:report]
    raise "Expected 0 violations, got #{report.total_violations}" unless report.total_violations == 0
    raise "Expected domain 'cv-roundtrip', got '#{report.domain}'" unless report.domain == state[:domain_name]
  end
end

Aver.register(ContractVerificationAdapter)

RSpec.describe "Contract verification acceptance", aver: ContractVerificationDomain do

  aver_test "extracts contract from static telemetry" do |ctx|
    ctx.when.extract_static_contract
    ctx.then.static_contract_correct
  end

  aver_test "extracts contract from parameterized telemetry" do |ctx|
    ctx.when.extract_parameterized_contract
    ctx.then.parameterized_contract_correct
  end

  aver_test "verify passes on matching traces" do |ctx|
    ctx.when.verify_matching_traces
    ctx.then.matching_traces_pass
  end

  aver_test "verify fails on missing span" do |ctx|
    ctx.when.verify_missing_span
    ctx.then.missing_span_detected
  end

  aver_test "verify fails on literal mismatch" do |ctx|
    ctx.when.verify_literal_mismatch
    ctx.then.literal_mismatch_detected
  end

  aver_test "verify fails on correlation violation" do |ctx|
    ctx.when.verify_correlation_violation
    ctx.then.correlation_violation_detected
  end

  aver_test "no matching traces produces violation" do |ctx|
    ctx.when.verify_no_matching_traces
    ctx.then.no_matching_traces_detected
  end

  aver_test "round-trip: extract, serialize to hash, verify from hash" do |ctx|
    ctx.when.round_trip_contract
    ctx.then.round_trip_passes
  end
end

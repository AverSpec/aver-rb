require "spec_helper"

ContractVerificationDomain = Aver.domain("contract-verification") do
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

ContractVerificationAdapter = Aver.implement(ContractVerificationDomain, protocol: Aver.unit { {} }) do
  # Shared helpers stored as lambdas on the adapter
  build_domain_with_telemetry = ->(name, markers_spec) do
    Aver.domain(name) do
      markers_spec.each do |m|
        action m[:name], telemetry: Aver::TelemetryExpectation.new(
          span: m[:span],
          attributes: m.fetch(:attributes, {})
        )
      end
    end
  end

  stub_collector = ->(spans) do
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

  build_protocol_with_collector = ->(collector) do
    proto = Aver::Protocol.new(name: "cv-test")
    proto.define_singleton_method(:setup) { {} }
    proto.define_singleton_method(:teardown) { |ctx| nil }
    proto.telemetry = collector
    proto
  end

  run_operations = ->(domain, adapter, protocol) do
    ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: protocol.setup, protocol: protocol)
    domain.markers.each_key do |marker_name|
      ctx.when.send(marker_name)
    end
    ctx
  end

  extract_results = ->(ctx, test_name: "cv-test") do
    [{ test_name: test_name, trace: ctx.trace }]
  end

  make_production_traces = ->(spans_per_trace) do
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

  handle(:extract_static_contract) do |state, p|
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = build_domain_with_telemetry.call("cv-static", [
      { name: :login, span: "auth.login", attributes: { "user.role" => "admin" } },
    ])
    collector = stub_collector.call([
      { name: "auth.login", attributes: { "user.role" => "admin" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = build_protocol_with_collector.call(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:login) { |ctx, p| "done" }
    end
    ctx = run_operations.call(d, a, proto)
    state[:contract] = Aver.extract_contract(d, extract_results.call(ctx))
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  handle(:extract_parameterized_contract) do |state, p|
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = build_domain_with_telemetry.call("cv-param", [
      { name: :signup, span: "user.signup", attributes: { "user.email" => "alice@test.com" } },
    ])
    collector = stub_collector.call([
      { name: "user.signup", attributes: { "user.email" => "alice@test.com" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = build_protocol_with_collector.call(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:signup) { |ctx, p| "done" }
    end
    ctx = run_operations.call(d, a, proto)
    state[:contract] = Aver.extract_contract(d, extract_results.call(ctx))
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  handle(:verify_matching_traces) do |state, p|
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = build_domain_with_telemetry.call("cv-match", [
      { name: :checkout, span: "order.checkout", attributes: { "amount" => "100" } },
    ])
    collector = stub_collector.call([
      { name: "order.checkout", attributes: { "amount" => "100" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = build_protocol_with_collector.call(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:checkout) { |ctx, p| "done" }
    end
    ctx = run_operations.call(d, a, proto)
    contract = Aver.extract_contract(d, extract_results.call(ctx))
    prod_traces = make_production_traces.call([
      [{ name: "order.checkout", attributes: { "amount" => "100" }, trace_id: "t1", span_id: "s1" }],
    ])
    state[:report] = Aver.verify_contract(contract, prod_traces)
    state[:domain_name] = "cv-match"
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  handle(:verify_missing_span) do |state, p|
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = build_domain_with_telemetry.call("cv-missing", [
      { name: :start, span: "checkout.start" },
      { name: :charge, span: "payment.charge" },
    ])
    collector = stub_collector.call([
      { name: "checkout.start", trace_id: "t1", span_id: "s1" },
      { name: "payment.charge", trace_id: "t1", span_id: "s2" },
    ])
    proto = build_protocol_with_collector.call(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:start) { |ctx, p| "done" }
      handle(:charge) { |ctx, p| "done" }
    end
    ctx = run_operations.call(d, a, proto)
    contract = Aver.extract_contract(d, extract_results.call(ctx))
    prod_traces = make_production_traces.call([
      [{ name: "checkout.start", trace_id: "t1", span_id: "s1" }],
    ])
    state[:report] = Aver.verify_contract(contract, prod_traces)
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  handle(:verify_literal_mismatch) do |state, p|
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = build_domain_with_telemetry.call("cv-literal", [
      { name: :cancel, span: "order.cancel", attributes: { "order.status" => "cancelled" } },
    ])
    collector = stub_collector.call([
      { name: "order.cancel", attributes: { "order.status" => "cancelled" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = build_protocol_with_collector.call(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:cancel) { |ctx, p| "done" }
    end
    ctx = run_operations.call(d, a, proto)
    contract = Aver.extract_contract(d, extract_results.call(ctx))
    prod_traces = make_production_traces.call([
      [{ name: "order.cancel", attributes: { "order.status" => "canceled" }, trace_id: "t1", span_id: "s1" }],
    ])
    state[:report] = Aver.verify_contract(contract, prod_traces)
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  handle(:verify_correlation_violation) do |state, p|
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = build_domain_with_telemetry.call("cv-corr", [
      { name: :login, span: "auth.login", attributes: { "user.email" => "alice@co.com" } },
      { name: :session, span: "auth.session", attributes: { "user.email" => "alice@co.com" } },
    ])
    collector = stub_collector.call([
      { name: "auth.login", attributes: { "user.email" => "alice@co.com" }, trace_id: "t1", span_id: "s1" },
      { name: "auth.session", attributes: { "user.email" => "alice@co.com" }, trace_id: "t1", span_id: "s2" },
    ])
    proto = build_protocol_with_collector.call(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:login) { |ctx, p| "done" }
      handle(:session) { |ctx, p| "done" }
    end
    ctx = run_operations.call(d, a, proto)
    contract = Aver.extract_contract(d, extract_results.call(ctx))
    contract.entries[0].spans.each do |span_exp|
      span_exp.attributes.each do |key, binding|
        binding.kind = "correlated"
        binding.symbol = :email
      end
    end
    prod_traces = make_production_traces.call([
      [
        { name: "auth.login", attributes: { "user.email" => "alice@co.com" }, trace_id: "t1", span_id: "s1" },
        { name: "auth.session", attributes: { "user.email" => "bob@co.com" }, trace_id: "t1", span_id: "s2" },
      ],
    ])
    state[:report] = Aver.verify_contract(contract, prod_traces)
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  handle(:verify_no_matching_traces) do |state, p|
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = build_domain_with_telemetry.call("cv-no-match", [
      { name: :expected_op, span: "expected.span" },
    ])
    collector = stub_collector.call([
      { name: "expected.span", trace_id: "t1", span_id: "s1" },
    ])
    proto = build_protocol_with_collector.call(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:expected_op) { |ctx, p| "done" }
    end
    ctx = run_operations.call(d, a, proto)
    contract = Aver.extract_contract(d, extract_results.call(ctx))
    prod_traces = make_production_traces.call([
      [{ name: "unrelated.span", trace_id: "t1", span_id: "s1" }],
    ])
    state[:report] = Aver.verify_contract(contract, prod_traces)
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  handle(:round_trip_contract) do |state, p|
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    d = build_domain_with_telemetry.call("cv-roundtrip", [
      { name: :op_one, span: "service.op_one", attributes: { "key" => "value" } },
    ])
    collector = stub_collector.call([
      { name: "service.op_one", attributes: { "key" => "value" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = build_protocol_with_collector.call(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:op_one) { |ctx, p| "done" }
    end
    ctx = run_operations.call(d, a, proto)
    contract = Aver.extract_contract(d, extract_results.call(ctx))

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

    prod_traces = make_production_traces.call([
      [{ name: "service.op_one", attributes: { "key" => "value" }, trace_id: "t1", span_id: "s1" }],
    ])
    state[:report] = Aver.verify_contract(rebuilt, prod_traces)
    state[:domain_name] = "cv-roundtrip"
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  handle(:static_contract_correct) do |state, p|
    contract = state[:contract]
    raise "Expected domain 'cv-static', got '#{contract.domain}'" unless contract.domain == "cv-static"
    raise "Expected 1 entry, got #{contract.entries.length}" unless contract.entries.length == 1
    raise "Expected 1 span, got #{contract.entries[0].spans.length}" unless contract.entries[0].spans.length == 1
    raise "Expected span 'auth.login', got '#{contract.entries[0].spans[0].name}'" unless contract.entries[0].spans[0].name == "auth.login"
  end

  handle(:parameterized_contract_correct) do |state, p|
    contract = state[:contract]
    raise "Expected 1 entry, got #{contract.entries.length}" unless contract.entries.length == 1
    span_exp = contract.entries[0].spans[0]
    raise "Expected span 'user.signup', got '#{span_exp.name}'" unless span_exp.name == "user.signup"
    raise "Expected literal kind, got '#{span_exp.attributes["user.email"].kind}'" unless span_exp.attributes["user.email"].kind == "literal"
    raise "Expected value 'alice@test.com', got '#{span_exp.attributes["user.email"].value}'" unless span_exp.attributes["user.email"].value == "alice@test.com"
  end

  handle(:matching_traces_pass) do |state, p|
    report = state[:report]
    raise "Expected 0 violations, got #{report.total_violations}" unless report.total_violations == 0
    raise "Expected domain 'cv-match', got '#{report.domain}'" unless report.domain == state[:domain_name]
  end

  handle(:missing_span_detected) do |state, p|
    report = state[:report]
    raise "Expected violations > 0, got #{report.total_violations}" unless report.total_violations > 0
    kinds = report.results.flat_map { |r| r.violations.map(&:kind) }
    raise "Expected 'missing-span' violation, got #{kinds.inspect}" unless kinds.include?("missing-span")
  end

  handle(:literal_mismatch_detected) do |state, p|
    report = state[:report]
    raise "Expected violations > 0, got #{report.total_violations}" unless report.total_violations > 0
    kinds = report.results.flat_map { |r| r.violations.map(&:kind) }
    raise "Expected 'literal-mismatch' violation, got #{kinds.inspect}" unless kinds.include?("literal-mismatch")
  end

  handle(:correlation_violation_detected) do |state, p|
    report = state[:report]
    raise "Expected violations > 0, got #{report.total_violations}" unless report.total_violations > 0
    kinds = report.results.flat_map { |r| r.violations.map(&:kind) }
    raise "Expected 'correlation-violation', got #{kinds.inspect}" unless kinds.include?("correlation-violation")
  end

  handle(:no_matching_traces_detected) do |state, p|
    report = state[:report]
    raise "Expected violations > 0, got #{report.total_violations}" unless report.total_violations > 0
    kinds = report.results.flat_map { |r| r.violations.map(&:kind) }
    raise "Expected 'no-matching-traces', got #{kinds.inspect}" unless kinds.include?("no-matching-traces")
  end

  handle(:round_trip_passes) do |state, p|
    report = state[:report]
    raise "Expected 0 violations, got #{report.total_violations}" unless report.total_violations == 0
    raise "Expected domain 'cv-roundtrip', got '#{report.domain}'" unless report.domain == state[:domain_name]
  end
end

Aver.configuration.adapters << ContractVerificationAdapter

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

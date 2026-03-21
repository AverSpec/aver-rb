require "spec_helper"

RSpec.describe "Contract verification acceptance" do
  # Helper: build a domain with telemetry on markers, run operations, extract contract
  def build_domain_with_telemetry(name, markers_spec)
    d = Aver.domain(name) do
      markers_spec.each do |m|
        action m[:name], telemetry: Aver::TelemetryExpectation.new(
          span: m[:span],
          attributes: m.fetch(:attributes, {})
        )
      end
    end
    d
  end

  def stub_collector(spans)
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

  def build_protocol_with_collector(collector)
    proto = Aver::Protocol.new(name: "cv-test")
    proto.define_singleton_method(:setup) { {} }
    proto.define_singleton_method(:teardown) { |ctx| nil }
    proto.telemetry = collector
    proto
  end

  def run_operations(domain, adapter, protocol)
    ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: protocol.setup, protocol: protocol)
    domain.markers.each_key do |marker_name|
      ctx.when.send(marker_name)
    end
    ctx
  end

  def extract_results(ctx, test_name: "cv-test")
    [{ test_name: test_name, trace: ctx.trace }]
  end

  def make_production_traces(spans_per_trace)
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

  it "extracts contract from static telemetry" do
    ENV["AVER_TELEMETRY_MODE"] = "fail"

    d = build_domain_with_telemetry("cv-static", [
      { name: :login, span: "auth.login", attributes: { "user.role" => "admin" } },
    ])
    collector = stub_collector([
      { name: "auth.login", attributes: { "user.role" => "admin" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = build_protocol_with_collector(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:login) { |ctx, p| "done" }
    end

    ctx = run_operations(d, a, proto)
    contract = Aver.extract_contract(d, extract_results(ctx))

    expect(contract.domain).to eq("cv-static")
    expect(contract.entries.length).to eq(1)
    expect(contract.entries[0].spans.length).to eq(1)
    expect(contract.entries[0].spans[0].name).to eq("auth.login")
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  it "extracts contract from parameterized telemetry" do
    ENV["AVER_TELEMETRY_MODE"] = "fail"

    d = build_domain_with_telemetry("cv-param", [
      { name: :signup, span: "user.signup", attributes: { "user.email" => "alice@test.com" } },
    ])
    collector = stub_collector([
      { name: "user.signup", attributes: { "user.email" => "alice@test.com" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = build_protocol_with_collector(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:signup) { |ctx, p| "done" }
    end

    ctx = run_operations(d, a, proto)
    contract = Aver.extract_contract(d, extract_results(ctx))

    expect(contract.entries.length).to eq(1)
    span_exp = contract.entries[0].spans[0]
    expect(span_exp.name).to eq("user.signup")
    expect(span_exp.attributes["user.email"].kind).to eq("literal")
    expect(span_exp.attributes["user.email"].value).to eq("alice@test.com")
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  it "verify passes on matching traces" do
    ENV["AVER_TELEMETRY_MODE"] = "fail"

    d = build_domain_with_telemetry("cv-match", [
      { name: :checkout, span: "order.checkout", attributes: { "amount" => "100" } },
    ])
    collector = stub_collector([
      { name: "order.checkout", attributes: { "amount" => "100" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = build_protocol_with_collector(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:checkout) { |ctx, p| "done" }
    end

    ctx = run_operations(d, a, proto)
    contract = Aver.extract_contract(d, extract_results(ctx))
    prod_traces = make_production_traces([
      [{ name: "order.checkout", attributes: { "amount" => "100" }, trace_id: "t1", span_id: "s1" }],
    ])

    report = Aver.verify_contract(contract, prod_traces)
    expect(report.total_violations).to eq(0)
    expect(report.domain).to eq("cv-match")
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  it "verify fails on missing span" do
    ENV["AVER_TELEMETRY_MODE"] = "fail"

    d = build_domain_with_telemetry("cv-missing", [
      { name: :start, span: "checkout.start" },
      { name: :charge, span: "payment.charge" },
    ])
    collector = stub_collector([
      { name: "checkout.start", trace_id: "t1", span_id: "s1" },
      { name: "payment.charge", trace_id: "t1", span_id: "s2" },
    ])
    proto = build_protocol_with_collector(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:start) { |ctx, p| "done" }
      handle(:charge) { |ctx, p| "done" }
    end

    ctx = run_operations(d, a, proto)
    contract = Aver.extract_contract(d, extract_results(ctx))

    # Production only has the first span
    prod_traces = make_production_traces([
      [{ name: "checkout.start", trace_id: "t1", span_id: "s1" }],
    ])

    report = Aver.verify_contract(contract, prod_traces)
    expect(report.total_violations).to be > 0
    kinds = report.results.flat_map { |r| r.violations.map(&:kind) }
    expect(kinds).to include("missing-span")
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  it "verify fails on literal mismatch" do
    ENV["AVER_TELEMETRY_MODE"] = "fail"

    d = build_domain_with_telemetry("cv-literal", [
      { name: :cancel, span: "order.cancel", attributes: { "order.status" => "cancelled" } },
    ])
    collector = stub_collector([
      { name: "order.cancel", attributes: { "order.status" => "cancelled" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = build_protocol_with_collector(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:cancel) { |ctx, p| "done" }
    end

    ctx = run_operations(d, a, proto)
    contract = Aver.extract_contract(d, extract_results(ctx))

    # Production has a different spelling
    prod_traces = make_production_traces([
      [{ name: "order.cancel", attributes: { "order.status" => "canceled" }, trace_id: "t1", span_id: "s1" }],
    ])

    report = Aver.verify_contract(contract, prod_traces)
    expect(report.total_violations).to be > 0
    kinds = report.results.flat_map { |r| r.violations.map(&:kind) }
    expect(kinds).to include("literal-mismatch")
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  it "verify fails on correlation violation" do
    ENV["AVER_TELEMETRY_MODE"] = "fail"

    d = build_domain_with_telemetry("cv-corr", [
      { name: :login, span: "auth.login", attributes: { "user.email" => "alice@co.com" } },
      { name: :session, span: "auth.session", attributes: { "user.email" => "alice@co.com" } },
    ])
    collector = stub_collector([
      { name: "auth.login", attributes: { "user.email" => "alice@co.com" }, trace_id: "t1", span_id: "s1" },
      { name: "auth.session", attributes: { "user.email" => "alice@co.com" }, trace_id: "t1", span_id: "s2" },
    ])
    proto = build_protocol_with_collector(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:login) { |ctx, p| "done" }
      handle(:session) { |ctx, p| "done" }
    end

    ctx = run_operations(d, a, proto)
    contract = Aver.extract_contract(d, extract_results(ctx))

    # Manually set correlated bindings on the extracted contract
    # (Ruby extract_contract produces "literal" bindings; to test correlation
    # we override the bindings to "correlated" with a shared symbol)
    contract.entries[0].spans.each do |span_exp|
      span_exp.attributes.each do |key, binding|
        binding.kind = "correlated"
        binding.symbol = :email
      end
    end

    # Production: same symbol maps to different values
    prod_traces = make_production_traces([
      [
        { name: "auth.login", attributes: { "user.email" => "alice@co.com" }, trace_id: "t1", span_id: "s1" },
        { name: "auth.session", attributes: { "user.email" => "bob@co.com" }, trace_id: "t1", span_id: "s2" },
      ],
    ])

    report = Aver.verify_contract(contract, prod_traces)
    expect(report.total_violations).to be > 0
    kinds = report.results.flat_map { |r| r.violations.map(&:kind) }
    expect(kinds).to include("correlation-violation")
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  it "no matching traces produces violation" do
    ENV["AVER_TELEMETRY_MODE"] = "fail"

    d = build_domain_with_telemetry("cv-no-match", [
      { name: :expected_op, span: "expected.span" },
    ])
    collector = stub_collector([
      { name: "expected.span", trace_id: "t1", span_id: "s1" },
    ])
    proto = build_protocol_with_collector(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:expected_op) { |ctx, p| "done" }
    end

    ctx = run_operations(d, a, proto)
    contract = Aver.extract_contract(d, extract_results(ctx))

    # Production traces have completely different spans
    prod_traces = make_production_traces([
      [{ name: "unrelated.span", trace_id: "t1", span_id: "s1" }],
    ])

    report = Aver.verify_contract(contract, prod_traces)
    expect(report.total_violations).to be > 0
    kinds = report.results.flat_map { |r| r.violations.map(&:kind) }
    expect(kinds).to include("no-matching-traces")
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end

  it "round-trip: extract, serialize to hash, verify from hash" do
    ENV["AVER_TELEMETRY_MODE"] = "fail"

    d = build_domain_with_telemetry("cv-roundtrip", [
      { name: :op_one, span: "service.op_one", attributes: { "key" => "value" } },
    ])
    collector = stub_collector([
      { name: "service.op_one", attributes: { "key" => "value" }, trace_id: "t1", span_id: "s1" },
    ])
    proto = build_protocol_with_collector(collector)
    a = Aver.implement(d, protocol: proto) do
      handle(:op_one) { |ctx, p| "done" }
    end

    ctx = run_operations(d, a, proto)
    contract = Aver.extract_contract(d, extract_results(ctx))

    # Serialize to hash and rebuild
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

    # Rebuild from hash
    rebuilt_entries = hash[:entries].map do |e|
      spans = e[:spans].map do |s|
        attrs = s[:attributes].transform_values { |a| Aver::AttributeBinding.new(kind: a[:kind], value: a[:value]) }
        Aver::SpanExpectation.new(name: s[:name], attributes: attrs, parent_name: s[:parent_name])
      end
      Aver::ContractEntry.new(test_name: e[:test_name], spans: spans)
    end
    rebuilt = Aver::BehavioralContract.new(domain: hash[:domain], entries: rebuilt_entries)

    # Verify with matching production traces
    prod_traces = make_production_traces([
      [{ name: "service.op_one", attributes: { "key" => "value" }, trace_id: "t1", span_id: "s1" }],
    ])

    report = Aver.verify_contract(rebuilt, prod_traces)
    expect(report.total_violations).to eq(0)
    expect(report.domain).to eq("cv-roundtrip")
  ensure
    ENV.delete("AVER_TELEMETRY_MODE")
  end
end

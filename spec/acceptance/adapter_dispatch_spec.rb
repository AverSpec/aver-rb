require "spec_helper"

RSpec.describe "Adapter dispatch acceptance" do
  it "dispatches actions through proxy" do
    d = Aver.domain("dispatch-action") { action :submit_order }
    p = Aver.unit { { orders: [] } }
    a = Aver.implement(d, protocol: p) do
      handle(:submit_order) { |ctx, payload| ctx[:orders] << payload }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)
    ctx.when.submit_order(id: "order-1")

    trace = ctx.trace
    expect(trace.length).to eq(1)
    expect(trace[0].kind).to eq("action")
    expect(trace[0].category).to eq("when")
    expect(trace[0].status).to eq("pass")
  end

  it "dispatches queries and returns results" do
    d = Aver.domain("dispatch-query") { query :get_status, returns: String }
    p = Aver.unit { {} }
    a = Aver.implement(d, protocol: p) do
      handle(:get_status) { |ctx, payload| "active" }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)
    result = ctx.query.get_status

    expect(result).to eq("active")
    expect(ctx.trace[0].kind).to eq("query")
    expect(ctx.trace[0].status).to eq("pass")
  end

  it "dispatches assertions through proxy" do
    d = Aver.domain("dispatch-assert") { assertion :is_valid }
    p = Aver.unit { {} }
    a = Aver.implement(d, protocol: p) do
      handle(:is_valid) { |ctx, payload| true }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)
    ctx.then.is_valid

    expect(ctx.trace[0].kind).to eq("assertion")
    expect(ctx.trace[0].status).to eq("pass")
  end

  it "failing assertion with no prior trace" do
    d = Aver.domain("dispatch-fail") { assertion :must_pass }
    p = Aver.unit { {} }
    a = Aver.implement(d, protocol: p) do
      handle(:must_pass) { |ctx, payload| raise "nope" }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)
    expect { ctx.then.must_pass }.to raise_error("nope")

    expect(ctx.trace.length).to eq(1)
    expect(ctx.trace[0].status).to eq("fail")
  end

  it "multiple adapters registered for same domain" do
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

    found = config.find_adapters(d)
    expect(found.length).to eq(2)
  end

  it "parent chain lookup finds parent adapter" do
    parent = Aver.domain("parent-chain") { action :base_op }
    child = parent.extend("child-chain") { action :child_op }

    p = Aver.unit { {} }
    parent_adapter = Aver.implement(parent, protocol: p) do
      handle(:base_op) { |ctx, payload| nil }
    end

    config = Aver::Configuration.new
    config.adapters << parent_adapter

    found = config.find_adapters(child)
    expect(found.length).to eq(1)
    expect(found[0]).to equal(parent_adapter)
    expect(child.parent).to eq(parent)
  end

  it "query returns typed result value" do
    d = Aver.domain("dispatch-typed") { query :get_count, returns: Integer }
    p = Aver.unit { {} }
    a = Aver.implement(d, protocol: p) do
      handle(:get_count) { |ctx, payload| 42 }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)
    result = ctx.query.get_count

    expect(result).to eq(42)
    expect(result).to be_a(Integer)
    expect(ctx.trace[0].kind).to eq("query")
    expect(ctx.trace[0].status).to eq("pass")
  end
end

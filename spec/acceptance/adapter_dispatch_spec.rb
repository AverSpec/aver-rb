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
end

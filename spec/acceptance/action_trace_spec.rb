require "spec_helper"

RSpec.describe "Action trace acceptance" do
  it "records complete trace across multiple operation types" do
    d = Aver.domain("trace-full") do
      action :setup_data
      query :fetch_data, returns: Hash
      assertion :data_valid
    end
    p = Aver.unit { {} }
    a = Aver.implement(d, protocol: p) do
      handle(:setup_data) { |ctx, payload| ctx[:data] = payload }
      handle(:fetch_data) { |ctx, payload| ctx[:data] }
      handle(:data_valid) { |ctx, payload| true }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)
    ctx.when.setup_data(seed: "abc")
    ctx.query.fetch_data
    ctx.then.data_valid

    trace = ctx.trace
    expect(trace.length).to eq(3)
    expect(trace[0].kind).to eq("action")
    expect(trace[0].category).to eq("when")
    expect(trace[0].status).to eq("pass")
    expect(trace[1].kind).to eq("query")
    expect(trace[1].category).to eq("query")
    expect(trace[2].kind).to eq("assertion")
    expect(trace[2].category).to eq("then")
  end

  it "records failure status when assertion fails" do
    d = Aver.domain("trace-fail") do
      action :prepare
      assertion :check_result
    end
    p = Aver.unit { {} }
    a = Aver.implement(d, protocol: p) do
      handle(:prepare) { |ctx, payload| nil }
      handle(:check_result) { |ctx, payload| raise "check failed" }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)
    ctx.when.prepare(data: "seed")
    expect { ctx.then.check_result }.to raise_error("check failed")

    trace = ctx.trace
    expect(trace.length).to eq(2)
    expect(trace[0].status).to eq("pass")
    expect(trace[1].status).to eq("fail")
  end

  it "records categorized trace with given/when/then" do
    d = Aver.domain("trace-cat") do
      action :seed_state
      action :perform_action
      assertion :verify_outcome
    end
    p = Aver.unit { {} }
    a = Aver.implement(d, protocol: p) do
      handle(:seed_state) { |ctx, payload| nil }
      handle(:perform_action) { |ctx, payload| nil }
      handle(:verify_outcome) { |ctx, payload| nil }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)
    ctx.given.seed_state(data: "initial")
    ctx.when.perform_action(data: "go")
    ctx.then.verify_outcome

    trace = ctx.trace
    expect(trace.length).to eq(3)
    expect(trace[0].category).to eq("given")
    expect(trace[1].category).to eq("when")
    expect(trace[2].category).to eq("then")
  end
end

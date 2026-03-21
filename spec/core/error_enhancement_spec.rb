require "spec_helper"

RSpec.describe "Error enhancement with formatted trace" do
  let(:domain) do
    Aver.domain("Enhanced") do
      action :setup_data
      assertion :verify
    end
  end

  def make_adapter
    p = Aver.unit { {} }
    a = Aver.implement(domain, protocol: p) do
      handle(:setup_data) { |ctx, payload| nil }
      handle(:verify) { |ctx, payload| raise "expected 42, got 0" }
    end
    [a, p]
  end

  it "trace appended to assertion error" do
    adapter, proto = make_adapter
    protocol_ctx = proto.setup
    ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx)

    ctx.when.setup_data(key: "value")
    expect { ctx.then.verify }.to raise_error(RuntimeError, /expected 42/)

    trace = ctx.trace
    expect(trace.length).to eq(2)
    expect(trace[0].status).to eq("pass")
    expect(trace[1].status).to eq("fail")

    trace_text = Aver.format_trace(trace)
    expect(trace_text).to include("Enhanced.setup_data")
    expect(trace_text).to include("Enhanced.verify")
    expect(trace_text).to include("[FAIL]")
  end

  it "enhancement includes all trace steps" do
    adapter, proto = make_adapter
    protocol_ctx = proto.setup
    ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx)

    ctx.when.setup_data(a: 1)
    ctx.when.setup_data(b: 2)
    expect { ctx.then.verify }.to raise_error(RuntimeError)

    trace = ctx.trace
    trace_text = Aver.format_trace(trace)
    lines = trace_text.strip.split("\n")
    expect(lines.length).to eq(3)
    expect(lines[0]).to include("[PASS]")
    expect(lines[1]).to include("[PASS]")
    expect(lines[2]).to include("[FAIL]")
  end

  it "no enhancement when trace is empty (only failing step)" do
    adapter, proto = make_adapter
    protocol_ctx = proto.setup
    ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx)

    expect { ctx.then.verify }.to raise_error(RuntimeError, /expected 42/)
    trace = ctx.trace
    expect(trace.length).to eq(1)
    trace_text = Aver.format_trace(trace)
    expect(trace_text).to include("[FAIL]")
  end
end

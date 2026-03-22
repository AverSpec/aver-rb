require "spec_helper"

RSpec.describe "Coverage tracking" do
  let(:domain) do
    Aver.domain("Cart") do
      action :add_item
      action :remove_item
      query :total, returns: Integer
      assertion :is_empty
    end
  end

  def make_ctx(d)
    p = Aver.unit { {} }
    handlers = {}
    d.markers.each_key { |name| handlers[name] = ->(ctx, payload) { nil } }
    a = Aver::AdapterInstance.new(domain: d, protocol: p, handlers: handlers)
    proto_ctx = p.setup
    Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto_ctx)
  end

  it "100% when all operations called" do
    ctx = make_ctx(domain)
    ctx.when.add_item(name: "Widget")
    ctx.when.remove_item(name: "Widget")
    ctx.query.total
    ctx.then.is_empty

    cov = ctx.get_coverage
    expect(cov[:domain]).to eq("Cart")
    expect(cov[:percentage]).to eq(100)
    expect(cov[:actions][:called]).to contain_exactly("add_item", "remove_item")
    expect(cov[:queries][:called]).to eq(["total"])
    expect(cov[:assertions][:called]).to eq(["is_empty"])
  end

  it "0% when no operations called" do
    ctx = make_ctx(domain)
    cov = ctx.get_coverage
    expect(cov[:percentage]).to eq(0)
    expect(cov[:actions][:called]).to eq([])
  end

  it "partial coverage" do
    ctx = make_ctx(domain)
    ctx.when.add_item(name: "Widget")
    ctx.query.total

    cov = ctx.get_coverage
    expect(cov[:percentage]).to eq(50)
  end

  it "empty domain is 100%" do
    d = Aver.domain("Empty")
    p = Aver.unit { {} }
    a = Aver::AdapterInstance.new(domain: d, protocol: p, handlers: {})
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)

    cov = ctx.get_coverage
    expect(cov[:percentage]).to eq(100)
  end

  it "does not double-count repeated calls" do
    ctx = make_ctx(domain)
    ctx.when.add_item(name: "A")
    ctx.when.add_item(name: "B")
    ctx.query.total

    cov = ctx.get_coverage
    expect(cov[:percentage]).to eq(50)
  end

  it "provides coverage breakdown per kind" do
    ctx = make_ctx(domain)
    ctx.when.add_item(name: "Widget")

    cov = ctx.get_coverage
    expect(cov[:actions][:total]).to contain_exactly("add_item", "remove_item")
    expect(cov[:actions][:called]).to eq(["add_item"])
    expect(cov[:queries][:total]).to eq(["total"])
    expect(cov[:queries][:called]).to eq([])
    expect(cov[:assertions][:total]).to eq(["is_empty"])
    expect(cov[:assertions][:called]).to eq([])
  end
end

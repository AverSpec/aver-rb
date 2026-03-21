require "spec_helper"

RSpec.describe "Coverage acceptance" do
  it "tracks coverage across a full test scenario" do
    d = Aver.domain("CoverageTest") do
      action :create_item
      action :delete_item
      query :get_items, returns: Array
      assertion :item_exists
    end
    p = Aver.unit { { items: [] } }
    a = Aver.implement(d, protocol: p) do
      handle(:create_item) { |ctx, payload| ctx[:items] << payload[:name] }
      handle(:delete_item) { |ctx, payload| ctx[:items].delete(payload[:name]) }
      handle(:get_items) { |ctx, payload| ctx[:items] }
      handle(:item_exists) { |ctx, payload| raise "not found" unless ctx[:items].include?(payload[:name]) }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)

    # Call 3 of 4 markers
    ctx.when.create_item(name: "Widget")
    items = ctx.query.get_items
    expect(items).to eq(["Widget"])
    ctx.then.item_exists(name: "Widget")

    cov = ctx.get_coverage
    expect(cov[:domain]).to eq("CoverageTest")
    expect(cov[:percentage]).to eq(75)
    expect(cov[:actions][:called]).to eq(["create_item"])
    expect(cov[:actions][:total]).to contain_exactly("create_item", "delete_item")
  end

  it "does not double-count repeated calls" do
    d = Aver.domain("CoverageDedup") do
      action :submit
      query :total, returns: Integer
      assertion :valid
    end
    p = Aver.unit { { items: [] } }
    a = Aver.implement(d, protocol: p) do
      handle(:submit) { |ctx, payload| ctx[:items] << payload }
      handle(:total) { |ctx, payload| ctx[:items].length }
      handle(:valid) { |ctx, payload| true }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)

    ctx.when.submit(name: "first")
    ctx.when.submit(name: "second")
    ctx.query.total

    cov = ctx.get_coverage
    # 2 of 3 markers covered (submit + total, valid uncalled) = 67%
    expect(cov[:percentage]).to eq(67)
  end

  it "reports per-kind breakdown" do
    d = Aver.domain("CoverageBreakdown") do
      action :a1
      action :a2
      query :q1, returns: Integer
      assertion :c1
    end
    p = Aver.unit { {} }
    a = Aver.implement(d, protocol: p) do
      handle(:a1) { |ctx, payload| nil }
      handle(:a2) { |ctx, payload| nil }
      handle(:q1) { |ctx, payload| 0 }
      handle(:c1) { |ctx, payload| true }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)

    ctx.when.a1

    cov = ctx.get_coverage
    expect(cov[:actions][:called].length).to eq(1)
    expect(cov[:actions][:total].length).to eq(2)
    expect(cov[:queries][:called].length).to eq(0)
    expect(cov[:queries][:total].length).to eq(1)
    expect(cov[:assertions][:called].length).to eq(0)
    expect(cov[:assertions][:total].length).to eq(1)
  end
end

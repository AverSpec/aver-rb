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
end

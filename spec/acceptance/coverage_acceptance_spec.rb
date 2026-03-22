require "spec_helper"

class CoverageDomain < Aver::Domain
  domain_name "coverage-test"
  action :run_full_coverage_scenario
  action :run_dedup_scenario
  action :run_breakdown_scenario
  assertion :full_coverage_correct
  assertion :dedup_coverage_correct
  assertion :breakdown_coverage_correct
end

class CoverageAcceptAdapter < Aver::Adapter
  domain CoverageDomain
  protocol :unit, -> { {} }

  def run_full_coverage_scenario(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "CoverageTest"
      action :create_item
      action :delete_item
      query :get_items, returns: Array
      assertion :item_exists
    end
    dd = d
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { { items: [] } }
      define_method(:create_item) { |ctx, **k| ctx[:items] << k[:name] }
      define_method(:delete_item) { |ctx, **k| ctx[:items].delete(k[:name]) }
      define_method(:get_items) { |ctx| ctx[:items] }
      define_method(:item_exists) { |ctx, **k| raise "not found" unless ctx[:items].include?(k[:name]) }
    end.new
    proto = Aver::UnitProtocol.new(-> { { items: [] } }, name: "unit")
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.when.create_item(name: "Widget")
    items = ctx.query.get_items
    state[:items] = items
    ctx.then.item_exists(name: "Widget")
    state[:coverage] = ctx.get_coverage
  end

  def run_dedup_scenario(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "CoverageDedup"
      action :submit
      query :total, returns: Integer
      assertion :valid
    end
    dd = d
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { { items: [] } }
      define_method(:submit) { |ctx, **k| ctx[:items] << k }
      define_method(:total) { |ctx| ctx[:items].length }
      define_method(:valid) { |ctx| true }
    end.new
    proto = Aver::UnitProtocol.new(-> { { items: [] } }, name: "unit")
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.when.submit(name: "first")
    ctx.when.submit(name: "second")
    ctx.query.total
    state[:coverage] = ctx.get_coverage
  end

  def run_breakdown_scenario(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "CoverageBreakdown"
      action :a1
      action :a2
      query :q1, returns: Integer
      assertion :c1
    end
    dd = d
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:a1) { |ctx, **k| nil }
      define_method(:a2) { |ctx, **k| nil }
      define_method(:q1) { |ctx| 0 }
      define_method(:c1) { |ctx| true }
    end.new
    proto = Aver::UnitProtocol.new(-> { {} }, name: "unit")
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.when.a1
    state[:coverage] = ctx.get_coverage
  end

  def full_coverage_correct(state, **kw)
    items = state[:items]
    raise "Expected items [\"Widget\"], got #{items.inspect}" unless items == ["Widget"]
    cov = state[:coverage]
    raise "Expected domain 'CoverageTest', got '#{cov[:domain]}'" unless cov[:domain] == "CoverageTest"
    raise "Expected 75% coverage, got #{cov[:percentage]}%" unless cov[:percentage] == 75
    raise "Expected called actions [\"create_item\"], got #{cov[:actions][:called].inspect}" unless cov[:actions][:called] == ["create_item"]
    total_actions = cov[:actions][:total].sort
    raise "Expected total actions [\"create_item\", \"delete_item\"], got #{total_actions.inspect}" unless total_actions == ["create_item", "delete_item"]
  end

  def dedup_coverage_correct(state, **kw)
    cov = state[:coverage]
    raise "Expected 67% coverage, got #{cov[:percentage]}%" unless cov[:percentage] == 67
  end

  def breakdown_coverage_correct(state, **kw)
    cov = state[:coverage]
    raise "Expected 1 called action, got #{cov[:actions][:called].length}" unless cov[:actions][:called].length == 1
    raise "Expected 2 total actions, got #{cov[:actions][:total].length}" unless cov[:actions][:total].length == 2
    raise "Expected 0 called queries, got #{cov[:queries][:called].length}" unless cov[:queries][:called].length == 0
    raise "Expected 1 total query, got #{cov[:queries][:total].length}" unless cov[:queries][:total].length == 1
    raise "Expected 0 called assertions, got #{cov[:assertions][:called].length}" unless cov[:assertions][:called].length == 0
    raise "Expected 1 total assertion, got #{cov[:assertions][:total].length}" unless cov[:assertions][:total].length == 1
  end
end

Aver.register(CoverageAcceptAdapter)

RSpec.describe "Coverage acceptance", aver: CoverageDomain do

  aver_test "tracks coverage across a full test scenario" do |ctx|
    ctx.when.run_full_coverage_scenario
    ctx.then.full_coverage_correct
  end

  aver_test "does not double-count repeated calls" do |ctx|
    ctx.when.run_dedup_scenario
    ctx.then.dedup_coverage_correct
  end

  aver_test "reports per-kind breakdown" do |ctx|
    ctx.when.run_breakdown_scenario
    ctx.then.breakdown_coverage_correct
  end
end

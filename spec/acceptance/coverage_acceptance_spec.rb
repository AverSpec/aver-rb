require "spec_helper"

CoverageDomain = Aver.domain("coverage-test") do
  action :run_full_coverage_scenario
  action :run_dedup_scenario
  action :run_breakdown_scenario
  assertion :full_coverage_correct
  assertion :dedup_coverage_correct
  assertion :breakdown_coverage_correct
end

CoverageAdapter = Aver.implement(CoverageDomain, protocol: Aver.unit { {} }) do
  handle(:run_full_coverage_scenario) do |state, p|
    d = Aver.domain("CoverageTest") do
      action :create_item
      action :delete_item
      query :get_items, returns: Array
      assertion :item_exists
    end
    proto = Aver.unit { { items: [] } }
    a = Aver.implement(d, protocol: proto) do
      handle(:create_item) { |ctx, payload| ctx[:items] << payload[:name] }
      handle(:delete_item) { |ctx, payload| ctx[:items].delete(payload[:name]) }
      handle(:get_items) { |ctx, payload| ctx[:items] }
      handle(:item_exists) { |ctx, payload| raise "not found" unless ctx[:items].include?(payload[:name]) }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.when.create_item(name: "Widget")
    items = ctx.query.get_items
    state[:items] = items
    ctx.then.item_exists(name: "Widget")
    state[:coverage] = ctx.get_coverage
  end

  handle(:run_dedup_scenario) do |state, p|
    d = Aver.domain("CoverageDedup") do
      action :submit
      query :total, returns: Integer
      assertion :valid
    end
    proto = Aver.unit { { items: [] } }
    a = Aver.implement(d, protocol: proto) do
      handle(:submit) { |ctx, payload| ctx[:items] << payload }
      handle(:total) { |ctx, payload| ctx[:items].length }
      handle(:valid) { |ctx, payload| true }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.when.submit(name: "first")
    ctx.when.submit(name: "second")
    ctx.query.total
    state[:coverage] = ctx.get_coverage
  end

  handle(:run_breakdown_scenario) do |state, p|
    d = Aver.domain("CoverageBreakdown") do
      action :a1
      action :a2
      query :q1, returns: Integer
      assertion :c1
    end
    proto = Aver.unit { {} }
    a = Aver.implement(d, protocol: proto) do
      handle(:a1) { |ctx, payload| nil }
      handle(:a2) { |ctx, payload| nil }
      handle(:q1) { |ctx, payload| 0 }
      handle(:c1) { |ctx, payload| true }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    ctx.when.a1
    state[:coverage] = ctx.get_coverage
  end

  handle(:full_coverage_correct) do |state, p|
    items = state[:items]
    raise "Expected items [\"Widget\"], got #{items.inspect}" unless items == ["Widget"]
    cov = state[:coverage]
    raise "Expected domain 'CoverageTest', got '#{cov[:domain]}'" unless cov[:domain] == "CoverageTest"
    raise "Expected 75% coverage, got #{cov[:percentage]}%" unless cov[:percentage] == 75
    raise "Expected called actions [\"create_item\"], got #{cov[:actions][:called].inspect}" unless cov[:actions][:called] == ["create_item"]
    total_actions = cov[:actions][:total].sort
    raise "Expected total actions [\"create_item\", \"delete_item\"], got #{total_actions.inspect}" unless total_actions == ["create_item", "delete_item"]
  end

  handle(:dedup_coverage_correct) do |state, p|
    cov = state[:coverage]
    raise "Expected 67% coverage, got #{cov[:percentage]}%" unless cov[:percentage] == 67
  end

  handle(:breakdown_coverage_correct) do |state, p|
    cov = state[:coverage]
    raise "Expected 1 called action, got #{cov[:actions][:called].length}" unless cov[:actions][:called].length == 1
    raise "Expected 2 total actions, got #{cov[:actions][:total].length}" unless cov[:actions][:total].length == 2
    raise "Expected 0 called queries, got #{cov[:queries][:called].length}" unless cov[:queries][:called].length == 0
    raise "Expected 1 total query, got #{cov[:queries][:total].length}" unless cov[:queries][:total].length == 1
    raise "Expected 0 called assertions, got #{cov[:assertions][:called].length}" unless cov[:assertions][:called].length == 0
    raise "Expected 1 total assertion, got #{cov[:assertions][:total].length}" unless cov[:assertions][:total].length == 1
  end
end

Aver.configuration.adapters << CoverageAdapter

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

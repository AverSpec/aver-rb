require "spec_helper"

RSpec.describe "Aver.composed_suite" do
  let(:tasks_domain) do
    Aver.domain("tasks") do
      action :create_task
      assertion :task_exists
    end
  end

  let(:users_domain) do
    Aver.domain("users") do
      action :create_user
      query :get_user, returns: Hash
    end
  end

  let(:tasks_protocol) { Aver.unit { [] } }
  let(:users_protocol) { Aver.unit { {} } }

  let(:tasks_adapter) do
    Aver.implement(tasks_domain, protocol: tasks_protocol) do
      handle(:create_task) { |ctx, p| ctx << (p || "task") }
      handle(:task_exists) { |ctx, p| true }
    end
  end

  let(:users_adapter) do
    Aver.implement(users_domain, protocol: users_protocol) do
      handle(:create_user) { |ctx, p| ctx[:user] = p }
      handle(:get_user) { |ctx, p| ctx[:user] }
    end
  end

  it "creates namespace proxies for each domain" do
    Aver.composed_suite(
      tasks: [tasks_domain, tasks_adapter],
      users: [users_domain, users_adapter]
    ) do |ctx|
      ctx.tasks.when.create_task(title: "test")
      ctx.users.when.create_user(name: "Alice")
      expect(ctx.trace.length).to eq(2)
    end
  end

  it "shares trace across namespaces" do
    Aver.composed_suite(
      tasks: [tasks_domain, tasks_adapter],
      users: [users_domain, users_adapter]
    ) do |ctx|
      ctx.tasks.when.create_task
      ctx.users.when.create_user(name: "Bob")
      trace = ctx.trace
      expect(trace[0].name).to include("tasks")
      expect(trace[1].name).to include("users")
    end
  end

  it "raises NoMethodError for unknown namespace" do
    Aver.composed_suite(
      tasks: [tasks_domain, tasks_adapter]
    ) do |ctx|
      expect { ctx.bogus }.to raise_error(NoMethodError, /No domain namespace 'bogus'/)
    end
  end

  it "enforces narrative restrictions per namespace" do
    Aver.composed_suite(
      tasks: [tasks_domain, tasks_adapter]
    ) do |ctx|
      expect { ctx.tasks.then.create_task }.to raise_error(TypeError)
    end
  end

  it "tears down in reverse order" do
    teardown_order = []
    p1 = Aver::Protocol.new(name: "p1")
    def p1.setup; []; end
    p1.define_singleton_method(:teardown) { |ctx| teardown_order = ctx; ctx << "p1" }

    p2 = Aver::Protocol.new(name: "p2")
    def p2.setup; []; end
    p2.define_singleton_method(:teardown) { |ctx| ctx; ctx << "p2" }

    # Use a shared array to track teardown order
    order = []

    proto1 = Aver.unit(name: "first") { order }
    proto2 = Aver.unit(name: "second") { order }

    d1 = Aver.domain("d1") { action :a1 }
    d2 = Aver.domain("d2") { action :a2 }
    a1 = Aver.implement(d1, protocol: proto1) { handle(:a1) { |ctx, p| } }
    a2 = Aver.implement(d2, protocol: proto2) { handle(:a2) { |ctx, p| } }

    proto1.define_singleton_method(:teardown) { |ctx| order << "first" }
    proto2.define_singleton_method(:teardown) { |ctx| order << "second" }

    Aver.composed_suite(
      first: [d1, a1],
      second: [d2, a2]
    ) { |ctx| }

    expect(order).to eq(["second", "first"])
  end

  it "dispatches queries through namespace" do
    Aver.composed_suite(
      users: [users_domain, users_adapter]
    ) do |ctx|
      ctx.users.when.create_user(name: "Queried")
      result = ctx.users.query.get_user
      expect(result).to eq({ name: "Queried" })
    end
  end
end

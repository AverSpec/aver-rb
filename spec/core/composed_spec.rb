require "spec_helper"

RSpec.describe "Aver.composed_suite" do
  let(:tasks_domain) do
    Class.new(Aver::Domain) do
      domain_name "tasks"
      action :create_task
      assertion :task_exists
    end
  end

  let(:users_domain) do
    Class.new(Aver::Domain) do
      domain_name "users"
      action :create_user
      query :get_user, returns: Hash
    end
  end

  let(:tasks_protocol) { Aver.unit { [] } }
  let(:users_protocol) { Aver.unit { {} } }

  let(:tasks_adapter) do
    d = tasks_domain
    klass = Class.new(Aver::Adapter) do
      domain d
      protocol :unit, -> { [] }
      define_method(:create_task) { |ctx, **kw| ctx << (kw.empty? ? "task" : kw) }
      define_method(:task_exists) { |ctx| true }
    end
    klass.new
  end

  let(:users_adapter) do
    d = users_domain
    klass = Class.new(Aver::Adapter) do
      domain d
      protocol :unit, -> { {} }
      define_method(:create_user) { |ctx, **kw| ctx[:user] = kw }
      define_method(:get_user) { |ctx| ctx[:user] }
    end
    klass.new
  end

  # composed_suite expects adapter objects that respond to .protocol
  # The OO adapter instances don't have .protocol, need to wrap them
  def wrap_adapter(adapter_inst, protocol)
    adapter_inst.define_singleton_method(:protocol) { protocol }
    adapter_inst
  end

  it "creates namespace proxies for each domain" do
    ta = wrap_adapter(tasks_adapter, tasks_protocol)
    ua = wrap_adapter(users_adapter, users_protocol)
    Aver.composed_suite(
      tasks: [tasks_domain, ta],
      users: [users_domain, ua]
    ) do |ctx|
      ctx.tasks.when.create_task(title: "test")
      ctx.users.when.create_user(name: "Alice")
      expect(ctx.trace.length).to eq(2)
    end
  end

  it "shares trace across namespaces" do
    ta = wrap_adapter(tasks_adapter, tasks_protocol)
    ua = wrap_adapter(users_adapter, users_protocol)
    Aver.composed_suite(
      tasks: [tasks_domain, ta],
      users: [users_domain, ua]
    ) do |ctx|
      ctx.tasks.when.create_task
      ctx.users.when.create_user(name: "Bob")
      trace = ctx.trace
      expect(trace[0].name).to include("tasks")
      expect(trace[1].name).to include("users")
    end
  end

  it "raises NoMethodError for unknown namespace" do
    ta = wrap_adapter(tasks_adapter, tasks_protocol)
    Aver.composed_suite(
      tasks: [tasks_domain, ta]
    ) do |ctx|
      expect { ctx.bogus }.to raise_error(NoMethodError, /No domain namespace 'bogus'/)
    end
  end

  it "enforces narrative restrictions per namespace" do
    ta = wrap_adapter(tasks_adapter, tasks_protocol)
    Aver.composed_suite(
      tasks: [tasks_domain, ta]
    ) do |ctx|
      expect { ctx.tasks.then.create_task }.to raise_error(TypeError)
    end
  end

  it "tears down in reverse order" do
    order = []
    proto1 = Aver.unit(name: "first") { order }
    proto2 = Aver.unit(name: "second") { order }

    d1 = Class.new(Aver::Domain) do
      domain_name "d1"
      action :a1
    end
    d2 = Class.new(Aver::Domain) do
      domain_name "d2"
      action :a2
    end

    dd1 = d1
    klass1 = Class.new(Aver::Adapter) do
      domain dd1
      protocol :unit, -> { [] }
      define_method(:a1) { |ctx, **kw| }
    end
    dd2 = d2
    klass2 = Class.new(Aver::Adapter) do
      domain dd2
      protocol :unit, -> { [] }
      define_method(:a2) { |ctx, **kw| }
    end

    a1 = klass1.new
    a1.define_singleton_method(:protocol) { proto1 }
    a2 = klass2.new
    a2.define_singleton_method(:protocol) { proto2 }

    proto1.define_singleton_method(:teardown) { |ctx| order << "first" }
    proto2.define_singleton_method(:teardown) { |ctx| order << "second" }

    Aver.composed_suite(
      first: [d1, a1],
      second: [d2, a2]
    ) { |ctx| }

    expect(order).to eq(["second", "first"])
  end

  it "dispatches queries through namespace" do
    ua = wrap_adapter(users_adapter, users_protocol)
    Aver.composed_suite(
      users: [users_domain, ua]
    ) do |ctx|
      ctx.users.when.create_user(name: "Queried")
      result = ctx.users.query.get_user
      expect(result).to eq({ name: "Queried" })
    end
  end
end

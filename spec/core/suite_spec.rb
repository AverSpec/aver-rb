require "spec_helper"

RSpec.describe "Suite dispatch + context" do
  let(:domain) do
    Class.new(Aver::Domain) do
      domain_name "Cart"
      action :add_item
      query :total, returns: Integer
      assertion :is_empty
    end
  end

  let(:protocol) { Aver.unit { { calls: [] } } }

  let(:adapter) do
    d = domain
    klass = Class.new(Aver::Adapter) do
      domain d
      protocol :unit, -> { { calls: [] } }
      define_method(:add_item) { |ctx, **kw| ctx[:calls] << "add:#{kw[:name]}" }
      define_method(:total) { |ctx| 42 }
      define_method(:is_empty) { |ctx| nil }
    end
    klass.new
  end

  def make_ctx(d = domain, a = adapter, p = protocol)
    proto_ctx = p.setup
    [Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto_ctx), proto_ctx]
  end

  describe "dispatching" do
    it "dispatches actions through when" do
      ctx, proto_ctx = make_ctx
      ctx.when.add_item(name: "Widget")
      expect(proto_ctx[:calls]).to include("add:Widget")
    end

    it "dispatches actions through given" do
      ctx, proto_ctx = make_ctx
      ctx.given.add_item(name: "Setup")
      expect(proto_ctx[:calls]).to include("add:Setup")
    end

    it "dispatches queries" do
      ctx, _ = make_ctx
      result = ctx.query.total
      expect(result).to eq(42)
    end

    it "dispatches assertions through then" do
      ctx, _ = make_ctx
      expect { ctx.then.is_empty }.not_to raise_error
    end

    it "dispatches parameterized queries" do
      filter_domain = Class.new(Aver::Domain) do
        domain_name "Filter"
        query :items_by_status, payload: Hash, returns: Array
      end
      items = { "active" => ["a", "b"], "done" => ["c"] }
      p = Aver.unit { {} }
      fd = filter_domain
      klass = Class.new(Aver::Adapter) do
        domain fd
        protocol :unit, -> { {} }
        define_method(:items_by_status) { |ctx, **kw| items[kw[:status]] }
      end
      a = klass.new
      proto_ctx = p.setup
      ctx = Aver::Context.new(domain: filter_domain, adapter: a, protocol_ctx: proto_ctx)
      result = ctx.query.items_by_status(status: "active")
      expect(result).to eq(["a", "b"])
    end

    it "works with domain that has no queries" do
      d = Class.new(Aver::Domain) do
        domain_name "ActionOnly"
        action :fire
        assertion :fired
      end
      state = { fired: false }
      p = Aver.unit { state }
      dd = d
      klass = Class.new(Aver::Adapter) do
        domain dd
        protocol :unit, -> { { fired: false } }
        define_method(:fire) { |ctx, **kw| ctx[:fired] = true }
        define_method(:fired) { |ctx| raise "not fired" unless ctx[:fired] }
      end
      a = klass.new
      proto_ctx = p.setup
      ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto_ctx)
      ctx.when.fire
      expect { ctx.then.fired }.not_to raise_error
      expect(proto_ctx[:fired]).to be true
    end
  end

  describe "trace recording" do
    it "records complete trace across operations" do
      ctx, _ = make_ctx
      ctx.when.add_item(name: "A")
      ctx.query.total
      ctx.then.is_empty

      trace = ctx.trace
      expect(trace.length).to eq(3)
      expect(trace[0].kind).to eq("action")
      expect(trace[0].category).to eq("when")
      expect(trace[0].name).to eq("Cart.add_item")
      expect(trace[0].payload).to eq({ name: "A" })
      expect(trace[0].status).to eq("pass")

      expect(trace[1].kind).to eq("query")
      expect(trace[1].category).to eq("query")
      expect(trace[1].result).to eq(42)

      expect(trace[2].kind).to eq("assertion")
      expect(trace[2].category).to eq("then")
    end

    it "records failure in trace" do
      d = Class.new(Aver::Domain) do
        domain_name "Fail"
        assertion :check
      end
      p = Aver.unit { {} }
      dd = d
      klass = Class.new(Aver::Adapter) do
        domain dd
        protocol :unit, -> { {} }
        define_method(:check) { |ctx| raise "boom" }
      end
      a = klass.new
      ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)
      expect { ctx.then.check }.to raise_error("boom")
      expect(ctx.trace[0].status).to eq("fail")
      expect(ctx.trace[0].error).to include("boom")
    end

    it "returns a copy of the trace" do
      ctx, _ = make_ctx
      ctx.when.add_item(name: "A")
      t1 = ctx.trace
      t2 = ctx.trace
      expect(t1).not_to equal(t2)
      expect(t1.length).to eq(t2.length)
    end

    it "records duration" do
      ctx, _ = make_ctx
      ctx.when.add_item(name: "A")
      expect(ctx.trace[0].duration_ms).to be >= 0
    end

    it "records given/when/then categories correctly" do
      ctx, _ = make_ctx
      ctx.given.add_item(name: "Setup")
      ctx.when.add_item(name: "Trigger")
      ctx.then.is_empty

      trace = ctx.trace
      expect(trace[0].category).to eq("given")
      expect(trace[1].category).to eq("when")
      expect(trace[2].category).to eq("then")
    end

    it "is empty before any calls" do
      ctx, _ = make_ctx
      expect(ctx.trace).to eq([])
    end
  end
end

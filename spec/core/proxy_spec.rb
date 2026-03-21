require "spec_helper"

RSpec.describe Aver::NarrativeProxy do
  let(:domain) do
    Aver.domain("tasks") do
      action :create_task
      query :get_task, returns: Hash
      assertion :task_exists
    end
  end

  let(:protocol) { Aver.unit { [] } }

  let(:adapter) do
    Aver.implement(domain, protocol: protocol) do
      handle(:create_task) { |ctx, p| ctx << p }
      handle(:get_task) { |ctx, p| { title: "found" } }
      handle(:task_exists) { |ctx, p| true }
    end
  end

  let(:protocol_ctx) { protocol.setup }
  let(:trace) { [] }
  let(:called_markers) { Set.new }

  describe "ctx.when dispatches actions" do
    it "calls the action handler" do
      proxy = Aver::NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: trace, category: :when, called_markers: called_markers)
      proxy.create_task(title: "test")
      expect(protocol_ctx).to eq([{ title: "test" }])
    end
  end

  describe "ctx.given dispatches actions and assertions" do
    it "allows actions" do
      proxy = Aver::NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: trace, category: :given, called_markers: called_markers)
      expect { proxy.create_task(title: "t") }.not_to raise_error
    end

    it "allows assertions" do
      proxy = Aver::NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: trace, category: :given, called_markers: called_markers)
      expect { proxy.task_exists }.not_to raise_error
    end
  end

  describe "ctx.then dispatches assertions" do
    it "allows assertions" do
      proxy = Aver::NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: trace, category: :then, called_markers: called_markers)
      expect { proxy.task_exists }.not_to raise_error
    end

    it "rejects actions" do
      proxy = Aver::NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: trace, category: :then, called_markers: called_markers)
      expect { proxy.create_task }.to raise_error(TypeError, /create_task.*action.*ctx\.then/)
    end
  end

  describe "ctx.query dispatches queries" do
    it "returns the query result" do
      proxy = Aver::NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: trace, category: :query, called_markers: called_markers)
      result = proxy.get_task
      expect(result).to eq({ title: "found" })
    end

    it "rejects actions" do
      proxy = Aver::NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: trace, category: :query, called_markers: called_markers)
      expect { proxy.create_task }.to raise_error(TypeError, /create_task.*action.*ctx\.query/)
    end
  end

  describe "missing marker" do
    it "raises NoMethodError for unknown markers" do
      proxy = Aver::NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: trace, category: :when, called_markers: called_markers)
      expect { proxy.nonexistent }.to raise_error(NoMethodError, /no marker 'nonexistent'/)
    end
  end

  describe "respond_to_missing?" do
    it "returns true for known markers" do
      proxy = Aver::NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: trace, category: :when, called_markers: called_markers)
      expect(proxy.respond_to?(:create_task)).to be true
    end

    it "returns false for unknown markers" do
      proxy = Aver::NarrativeProxy.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, trace: trace, category: :when, called_markers: called_markers)
      expect(proxy.respond_to?(:bogus)).to be false
    end
  end

  describe "keyword args vs hash args" do
    it "handles keyword args" do
      received = nil
      d = Aver.domain("kw") { action :go }
      a = Aver.implement(d, protocol: protocol) { handle(:go) { |ctx, p| received = p } }
      proxy = Aver::NarrativeProxy.new(domain: d, adapter: a, protocol_ctx: protocol_ctx, trace: trace, category: :when, called_markers: called_markers)
      proxy.go(x: 1, y: 2)
      expect(received).to eq({ x: 1, y: 2 })
    end
  end
end

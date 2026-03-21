require "spec_helper"

RSpec.describe Aver::TraceEntry do
  describe "structure" do
    it "stores all fields" do
      entry = Aver::TraceEntry.new(
        kind: "action", category: "when", name: "tasks.create_task",
        payload: { title: "test" }, status: "pass", duration_ms: 1.5,
        result: "ok", telemetry: { span: "abc" }
      )
      expect(entry.kind).to eq("action")
      expect(entry.category).to eq("when")
      expect(entry.name).to eq("tasks.create_task")
      expect(entry.payload).to eq({ title: "test" })
      expect(entry.status).to eq("pass")
      expect(entry.duration_ms).to eq(1.5)
      expect(entry.result).to eq("ok")
      expect(entry.telemetry).to eq({ span: "abc" })
    end

    it "defaults status to pass" do
      entry = Aver::TraceEntry.new(kind: "action", category: "when", name: "x")
      expect(entry.status).to eq("pass")
    end

    it "defaults duration_ms to 0" do
      entry = Aver::TraceEntry.new(kind: "action", category: "when", name: "x")
      expect(entry.duration_ms).to eq(0.0)
    end

    it "defaults payload to nil" do
      entry = Aver::TraceEntry.new(kind: "action", category: "when", name: "x")
      expect(entry.payload).to be_nil
    end

    it "defaults error to nil" do
      entry = Aver::TraceEntry.new(kind: "action", category: "when", name: "x")
      expect(entry.error).to be_nil
    end
  end

  describe "trace recording through proxy" do
    let(:domain) { Aver.domain("t") { action :go; assertion :check } }
    let(:protocol) { Aver.unit { Object.new } }

    it "records pass entries" do
      adapter = Aver.implement(domain, protocol: protocol) do
        handle(:go) { |ctx, p| "done" }
        handle(:check) { |ctx, p| true }
      end
      ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: protocol.setup)
      ctx.when.go(val: 1)
      entries = ctx.trace
      expect(entries.length).to eq(1)
      expect(entries[0].status).to eq("pass")
      expect(entries[0].name).to eq("t.go")
      expect(entries[0].duration_ms).to be > 0
    end

    it "records fail entries" do
      adapter = Aver.implement(domain, protocol: protocol) do
        handle(:go) { |ctx, p| raise "boom" }
        handle(:check) { |ctx, p| }
      end
      ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: protocol.setup)
      expect { ctx.when.go }.to raise_error("boom")
      entries = ctx.trace
      expect(entries.length).to eq(1)
      expect(entries[0].status).to eq("fail")
      expect(entries[0].error).to eq("boom")
    end

    it "records payload" do
      adapter = Aver.implement(domain, protocol: protocol) do
        handle(:go) { |ctx, p| }
        handle(:check) { |ctx, p| }
      end
      ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: protocol.setup)
      ctx.when.go(x: 42)
      expect(ctx.trace[0].payload).to eq({ x: 42 })
    end
  end
end

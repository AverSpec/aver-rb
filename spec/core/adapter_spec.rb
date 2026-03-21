require "spec_helper"

RSpec.describe Aver::Adapter do
  let(:domain) do
    Aver.domain("tasks") do
      action :create_task
      assertion :task_exists
    end
  end

  let(:protocol) { Aver.unit { Object.new } }

  describe "building" do
    it "creates an adapter with all handlers" do
      adapter = Aver.implement(domain, protocol: protocol) do
        handle(:create_task) { |ctx, p| }
        handle(:task_exists) { |ctx, p| }
      end
      expect(adapter).to be_a(Aver::Adapter)
    end

    it "exposes the adapter name from the protocol" do
      adapter = Aver.implement(domain, protocol: protocol) do
        handle(:create_task) { |ctx, p| }
        handle(:task_exists) { |ctx, p| }
      end
      expect(adapter.name).to eq("unit")
    end

    it "exposes the domain name" do
      adapter = Aver.implement(domain, protocol: protocol) do
        handle(:create_task) { |ctx, p| }
        handle(:task_exists) { |ctx, p| }
      end
      expect(adapter.domain_name).to eq("tasks")
    end

    it "raises on missing handlers" do
      expect {
        Aver.implement(domain, protocol: protocol) do
          handle(:create_task) { |ctx, p| }
        end
      }.to raise_error(Aver::AdapterError, /Missing handlers.*task_exists/)
    end

    it "raises on extra handlers" do
      expect {
        Aver.implement(domain, protocol: protocol) do
          handle(:create_task) { |ctx, p| }
          handle(:task_exists) { |ctx, p| }
          handle(:bogus) { |ctx, p| }
        end
      }.to raise_error(Aver::AdapterError, /Extra handlers.*bogus/)
    end
  end

  describe "execution" do
    it "calls the handler with ctx and payload" do
      called_with = nil
      adapter = Aver.implement(domain, protocol: protocol) do
        handle(:create_task) { |ctx, p| called_with = p }
        handle(:task_exists) { |ctx, p| }
      end
      adapter.execute(:create_task, :fake_ctx, { title: "test" })
      expect(called_with).to eq({ title: "test" })
    end

    it "returns the handler result" do
      adapter = Aver.implement(domain, protocol: protocol) do
        handle(:create_task) { |ctx, p| "created" }
        handle(:task_exists) { |ctx, p| }
      end
      expect(adapter.execute(:create_task, :fake_ctx, nil)).to eq("created")
    end

    it "raises on unknown marker" do
      adapter = Aver.implement(domain, protocol: protocol) do
        handle(:create_task) { |ctx, p| }
        handle(:task_exists) { |ctx, p| }
      end
      expect { adapter.execute(:nope, :ctx, nil) }.to raise_error(/No handler for nope/)
    end
  end
end

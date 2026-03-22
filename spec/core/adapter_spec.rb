require "spec_helper"

RSpec.describe Aver::Adapter do
  let(:domain) do
    Class.new(Aver::Domain) do
      domain_name "tasks"
      action :create_task
      assertion :task_exists
    end
  end

  describe "building" do
    it "creates an adapter with all handlers" do
      d = domain
      adapter_class = Class.new(Aver::Adapter) do
        domain d
        protocol :unit, -> { Object.new }
        define_method(:create_task) { |ctx, **kw| }
        define_method(:task_exists) { |ctx, **kw| }
      end
      expect { adapter_class.validate! }.not_to raise_error
    end

    it "exposes the adapter name from the protocol" do
      d = domain
      adapter_class = Class.new(Aver::Adapter) do
        domain d
        protocol :unit, -> { Object.new }
        define_method(:create_task) { |ctx, **kw| }
        define_method(:task_exists) { |ctx, **kw| }
      end
      expect(adapter_class.protocol_name).to eq("unit")
    end

    it "exposes the domain class" do
      d = domain
      adapter_class = Class.new(Aver::Adapter) do
        domain d
        protocol :unit, -> { Object.new }
        define_method(:create_task) { |ctx, **kw| }
        define_method(:task_exists) { |ctx, **kw| }
      end
      expect(adapter_class.domain).to eq(d)
    end

    it "raises on missing handlers" do
      d = domain
      adapter_class = Class.new(Aver::Adapter) do
        domain d
        protocol :unit, -> { Object.new }
        define_method(:create_task) { |ctx, **kw| }
      end
      expect { adapter_class.validate! }.to raise_error(Aver::AdapterError, /Missing handlers.*task_exists/)
    end

    it "raises on extra handlers" do
      d = domain
      adapter_class = Class.new(Aver::Adapter) do
        domain d
        protocol :unit, -> { Object.new }
        define_method(:create_task) { |ctx, **kw| }
        define_method(:task_exists) { |ctx, **kw| }
        define_method(:bogus) { |ctx, **kw| }
      end
      expect { adapter_class.validate! }.to raise_error(Aver::AdapterError, /Extra handlers.*bogus/)
    end
  end

  describe "execution" do
    it "calls the handler with ctx and payload" do
      called_with = nil
      d = domain
      adapter_class = Class.new(Aver::Adapter) do
        domain d
        protocol :unit, -> { Object.new }
        define_method(:create_task) { |ctx, **kw| called_with = kw }
        define_method(:task_exists) { |ctx, **kw| }
      end
      adapter = adapter_class.new
      adapter.execute(:create_task, :fake_ctx, { title: "test" })
      expect(called_with).to eq({ title: "test" })
    end

    it "returns the handler result" do
      d = domain
      adapter_class = Class.new(Aver::Adapter) do
        domain d
        protocol :unit, -> { Object.new }
        define_method(:create_task) { |ctx, **kw| "created" }
        define_method(:task_exists) { |ctx, **kw| }
      end
      adapter = adapter_class.new
      expect(adapter.execute(:create_task, :fake_ctx, nil)).to eq("created")
    end

    it "raises on unknown marker" do
      d = domain
      adapter_class = Class.new(Aver::Adapter) do
        domain d
        protocol :unit, -> { Object.new }
        define_method(:create_task) { |ctx, **kw| }
        define_method(:task_exists) { |ctx, **kw| }
      end
      adapter = adapter_class.new
      expect { adapter.execute(:nope, :ctx, nil) }.to raise_error(NoMethodError)
    end
  end

  describe "Aver::Adapt alias" do
    it "is the same class as Aver::Adapter" do
      expect(Aver::Adapt).to equal(Aver::Adapter)
    end

    it "works as a base class" do
      d = domain
      adapter_class = Class.new(Aver::Adapt) do
        domain d
        protocol :unit, -> { Object.new }
        define_method(:create_task) { |ctx, **kw| }
        define_method(:task_exists) { |ctx, **kw| }
      end
      expect { adapter_class.validate! }.not_to raise_error
    end
  end
end

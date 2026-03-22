require "spec_helper"

RSpec.describe "Registry snapshot and restore" do
  let(:domain) do
    Class.new(Aver::Domain) do
      domain_name "SnapDomain"
      action :do_thing
    end
  end

  let(:adapter_class) do
    d = domain
    Class.new(Aver::Adapter) do
      domain d
      protocol :unit, -> { nil }
      define_method(:do_thing) { |ctx| nil }
    end
  end

  before(:each) { Aver.configuration.reset! }
  after(:each) { Aver.configuration.reset! }

  it "snapshot captures current state" do
    Aver.configuration.register(adapter_class)
    Aver.configuration.teardown_failure_mode = :warn

    snap = Aver.configuration.snapshot
    expect(snap[:adapter_classes].length).to eq(1)
    expect(snap[:adapter_classes][0]).to equal(adapter_class)
    expect(snap[:teardown_failure_mode]).to eq(:warn)
  end

  it "restore returns to previous state" do
    snap = Aver.configuration.snapshot
    expect(snap[:adapter_classes].length).to eq(0)

    Aver.configuration.register(adapter_class)
    expect(Aver.configuration.find_adapters(domain).length).to eq(1)

    Aver.configuration.restore(snap)
    expect(Aver.configuration.find_adapters(domain).length).to eq(0)
    expect(Aver.configuration.teardown_failure_mode).to eq(:fail)
  end

  it "restore clears adapters added after snapshot" do
    Aver.configuration.register(adapter_class)
    snap = Aver.configuration.snapshot

    # Create a second adapter class
    d = domain
    adapter_class2 = Class.new(Aver::Adapter) do
      domain d
      protocol :unit, -> { nil }
      define_method(:do_thing) { |ctx| nil }
    end
    Aver.configuration.register(adapter_class2)
    expect(Aver.configuration.find_adapters(domain).length).to eq(2)

    Aver.configuration.restore(snap)
    expect(Aver.configuration.find_adapters(domain).length).to eq(1)
    expect(Aver.configuration.find_adapters(domain)[0].adapter_class).to equal(adapter_class)
  end

  it "snapshot isolates from mutations" do
    Aver.configuration.register(adapter_class)

    snap = Aver.configuration.snapshot

    Aver.configuration.reset!
    Aver.configuration.teardown_failure_mode = :warn

    expect(snap[:adapter_classes].length).to eq(1)
    expect(snap[:teardown_failure_mode]).to eq(:fail)

    Aver.configuration.restore(snap)
    expect(Aver.configuration.find_adapters(domain).length).to eq(1)
    expect(Aver.configuration.teardown_failure_mode).to eq(:fail)
  end
end

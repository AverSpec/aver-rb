require "spec_helper"

RSpec.describe "Configuration snapshot/restore" do
  let(:config) { Aver::Configuration.new }

  let(:domain) do
    Class.new(Aver::Domain) do
      domain_name "tasks"
      action :go
    end
  end

  let(:adapter_class) do
    d = domain
    Class.new(Aver::Adapter) do
      domain d
      protocol :unit, -> { nil }
      define_method(:go) { |ctx| }
    end
  end

  it "snapshots current state" do
    config.register(adapter_class)
    config.teardown_failure_mode = :warn
    snap = config.snapshot
    expect(snap[:adapter_classes].length).to eq(1)
    expect(snap[:teardown_failure_mode]).to eq(:warn)
  end

  it "restores from snapshot" do
    config.register(adapter_class)
    config.teardown_failure_mode = :warn
    snap = config.snapshot

    config.reset!
    expect(config.find_adapters(domain)).to be_empty
    expect(config.teardown_failure_mode).to eq(:fail)

    config.restore(snap)
    expect(config.find_adapters(domain).length).to eq(1)
    expect(config.teardown_failure_mode).to eq(:warn)
  end

  it "snapshot is independent of original" do
    config.register(adapter_class)
    snap = config.snapshot
    config.reset!
    expect(snap[:adapter_classes].length).to eq(1)
  end
end

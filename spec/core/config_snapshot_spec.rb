require "spec_helper"

RSpec.describe "Configuration snapshot/restore" do
  let(:config) { Aver::Configuration.new }
  let(:domain) { Aver.domain("tasks") { action :go } }
  let(:protocol) { Aver.unit { nil } }
  let(:adapter) do
    Aver.implement(domain, protocol: protocol) do
      handle(:go) { |ctx, p| }
    end
  end

  it "snapshots current state" do
    config.adapters << adapter
    config.teardown_failure_mode = :warn
    snap = config.snapshot
    expect(snap[:adapters].length).to eq(1)
    expect(snap[:teardown_failure_mode]).to eq(:warn)
  end

  it "restores from snapshot" do
    config.adapters << adapter
    config.teardown_failure_mode = :warn
    snap = config.snapshot

    config.reset!
    expect(config.adapters).to be_empty
    expect(config.teardown_failure_mode).to eq(:fail)

    config.restore(snap)
    expect(config.adapters.length).to eq(1)
    expect(config.teardown_failure_mode).to eq(:warn)
  end

  it "snapshot is independent of original" do
    config.adapters << adapter
    snap = config.snapshot
    config.adapters.clear
    expect(snap[:adapters].length).to eq(1)
  end
end

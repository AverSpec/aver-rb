require "spec_helper"

RSpec.describe "Registry snapshot and restore" do
  let(:domain) { Aver.domain("SnapDomain") { action :do_thing } }
  let(:protocol) { Aver.unit { nil } }

  def make_adapter
    Aver.implement(domain, protocol: protocol) do
      handle(:do_thing) { |ctx, p| nil }
    end
  end

  before(:each) { Aver.configuration.reset! }
  after(:each) { Aver.configuration.reset! }

  it "snapshot captures current state" do
    adapter = make_adapter
    Aver.configuration.adapters << adapter
    Aver.configuration.teardown_failure_mode = :warn

    snap = Aver.configuration.snapshot
    expect(snap[:adapters].length).to eq(1)
    expect(snap[:adapters][0]).to equal(adapter)
    expect(snap[:teardown_failure_mode]).to eq(:warn)
  end

  it "restore returns to previous state" do
    snap = Aver.configuration.snapshot
    expect(snap[:adapters].length).to eq(0)

    adapter = make_adapter
    Aver.configuration.adapters << adapter
    expect(Aver.configuration.adapters.length).to eq(1)

    Aver.configuration.restore(snap)
    expect(Aver.configuration.adapters.length).to eq(0)
    expect(Aver.configuration.teardown_failure_mode).to eq(:fail)
  end

  it "restore clears adapters added after snapshot" do
    adapter1 = make_adapter
    Aver.configuration.adapters << adapter1
    snap = Aver.configuration.snapshot

    adapter2 = make_adapter
    Aver.configuration.adapters << adapter2
    expect(Aver.configuration.adapters.length).to eq(2)

    Aver.configuration.restore(snap)
    expect(Aver.configuration.adapters.length).to eq(1)
    expect(Aver.configuration.adapters[0]).to equal(adapter1)
  end

  it "snapshot isolates from mutations" do
    adapter = make_adapter
    Aver.configuration.adapters << adapter

    snap = Aver.configuration.snapshot

    Aver.configuration.adapters.clear
    Aver.configuration.teardown_failure_mode = :warn

    expect(snap[:adapters].length).to eq(1)
    expect(snap[:teardown_failure_mode]).to eq(:fail)

    Aver.configuration.restore(snap)
    expect(Aver.configuration.adapters.length).to eq(1)
    expect(Aver.configuration.teardown_failure_mode).to eq(:fail)
  end
end

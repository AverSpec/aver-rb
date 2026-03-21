require "spec_helper"

RSpec.describe "with_fixture" do
  def fake_protocol(telemetry: nil)
    proto = Class.new(Aver::Protocol) do
      attr_accessor :custom_ext
      define_method(:name) { "fake" }
      define_method(:setup) { { value: 42 } }
      define_method(:teardown) { |ctx| nil }
    end.new
    proto.telemetry = telemetry
    proto.custom_ext = "some_extension"
    proto
  end

  def bare_protocol
    proto = Aver::Protocol.new(name: "bare")
    proto.define_singleton_method(:setup) { nil }
    proto.define_singleton_method(:teardown) { |ctx| nil }
    proto
  end

  def throwing_protocol
    proto = Aver::Protocol.new(name: "throwing")
    proto.define_singleton_method(:setup) { nil }
    proto.define_singleton_method(:teardown) { |ctx| raise "teardown boom" }
    proto
  end

  it "passes through protocol telemetry" do
    collector = Object.new
    proto = fake_protocol(telemetry: collector)
    wrapped = Aver.with_fixture(proto, before: -> {})

    expect(wrapped.telemetry).not_to be_nil
    expect(wrapped.telemetry).to equal(collector)
  end

  it "after runs even if teardown throws" do
    calls = []
    proto = throwing_protocol
    wrapped = Aver.with_fixture(proto, after: -> { calls << "after" })

    ctx = wrapped.setup
    expect { wrapped.teardown(ctx) }.to raise_error(RuntimeError, /teardown boom/)
    expect(calls).to include("after")
  end

  it "bare protocol without hooks works" do
    calls = []
    proto = bare_protocol
    wrapped = Aver.with_fixture(
      proto,
      before: -> { calls << "before" },
      after: -> { calls << "after" }
    )

    ctx = wrapped.setup
    wrapped.teardown(ctx)
    expect(calls).to eq(["before", "after"])
  end

  it "after_setup receives correct context" do
    received = {}
    proto = fake_protocol
    wrapped = Aver.with_fixture(
      proto,
      after_setup: ->(ctx) { received.merge!(ctx) }
    )

    ctx = wrapped.setup
    expect(received).to eq({ value: 42 })
    expect(ctx).to eq({ value: 42 })
  end

  it "full lifecycle order" do
    calls = []
    tracking = Class.new(Aver::Protocol) do
      define_method(:name) { "tracking" }
      define_method(:setup) do
        calls << "setup"
        { value: 42 }
      end
      define_method(:teardown) { |ctx| calls << "teardown" }
    end.new

    wrapped = Aver.with_fixture(
      tracking,
      before: -> { calls << "before" },
      after_setup: ->(ctx) { calls << "afterSetup" },
      after: -> { calls << "after" }
    )

    ctx = wrapped.setup
    wrapped.teardown(ctx)

    expect(calls).to eq(["before", "setup", "afterSetup", "teardown", "after"])
  end
end

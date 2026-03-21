require "spec_helper"

RSpec.describe Aver::Protocol do
  describe "base protocol" do
    it "has a default name" do
      protocol = Aver::Protocol.new
      expect(protocol.name).to eq("unknown")
    end

    it "raises on setup" do
      protocol = Aver::Protocol.new
      expect { protocol.setup }.to raise_error(NotImplementedError)
    end

    it "teardown is a no-op" do
      protocol = Aver::Protocol.new
      expect { protocol.teardown(nil) }.not_to raise_error
    end
  end

  describe Aver::UnitProtocol do
    it "creates a fresh context on each setup call" do
      protocol = Aver.unit { Object.new }
      ctx1 = protocol.setup
      ctx2 = protocol.setup
      expect(ctx1).not_to equal(ctx2)
    end

    it "returns the factory result" do
      protocol = Aver.unit { 42 }
      expect(protocol.setup).to eq(42)
    end

    it "has default name 'unit'" do
      protocol = Aver.unit { nil }
      expect(protocol.name).to eq("unit")
    end

    it "accepts a custom name" do
      protocol = Aver.unit(name: "custom") { nil }
      expect(protocol.name).to eq("custom")
    end
  end
end

require "spec_helper"

RSpec.describe Aver::Configuration do
  let(:config) { Aver::Configuration.new }

  let(:domain) { Aver.domain("tasks") { action :go } }
  let(:protocol) { Aver.unit { nil } }
  let(:adapter) do
    Aver.implement(domain, protocol: protocol) do
      handle(:go) { |ctx, p| }
    end
  end

  describe "register and find" do
    it "registers an adapter" do
      config.adapters << adapter
      expect(config.adapters.length).to eq(1)
    end

    it "finds adapters by domain identity" do
      config.adapters << adapter
      found = config.find_adapters(domain)
      expect(found).to eq([adapter])
    end

    it "returns empty for unknown domain" do
      other = Aver.domain("other") { action :nope }
      expect(config.find_adapters(other)).to eq([])
    end
  end

  describe "parent chain lookup" do
    it "finds adapters registered on parent domain" do
      child = domain.extend("child") { assertion :check }
      config.adapters << adapter
      found = config.find_adapters(child)
      expect(found).to eq([adapter])
    end
  end

  describe "reset" do
    it "clears all adapters" do
      config.adapters << adapter
      config.reset!
      expect(config.adapters).to eq([])
    end

    it "resets teardown_failure_mode to :fail" do
      config.teardown_failure_mode = :warn
      config.reset!
      expect(config.teardown_failure_mode).to eq(:fail)
    end
  end
end

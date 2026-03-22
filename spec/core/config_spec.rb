require "spec_helper"

RSpec.describe Aver::Configuration do
  let(:config) { Aver::Configuration.new }

  let(:domain) do
    Class.new(Aver::Domain) do
      domain_name "tasks"
      action :go
    end
  end

  let(:protocol) { Aver.unit { nil } }

  let(:adapter_class) do
    d = domain
    Class.new(Aver::Adapter) do
      domain d
      protocol :unit, -> { nil }
      define_method(:go) { |ctx| }
    end
  end

  describe "register and find" do
    it "registers an adapter class" do
      config.register(adapter_class)
      found = config.find_adapters(domain)
      expect(found.length).to eq(1)
    end

    it "finds adapters by domain identity" do
      config.register(adapter_class)
      found = config.find_adapters(domain)
      expect(found.length).to eq(1)
      expect(found[0].adapter_class).to eq(adapter_class)
    end

    it "returns empty for unknown domain" do
      other = Class.new(Aver::Domain) do
        domain_name "other"
        action :nope
      end
      expect(config.find_adapters(other)).to eq([])
    end
  end

  describe "reset" do
    it "clears all adapters" do
      config.register(adapter_class)
      config.reset!
      expect(config.find_adapters(domain)).to eq([])
    end

    it "resets teardown_failure_mode to :fail" do
      config.teardown_failure_mode = :warn
      config.reset!
      expect(config.teardown_failure_mode).to eq(:fail)
    end
  end
end

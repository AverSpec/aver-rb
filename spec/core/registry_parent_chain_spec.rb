require "spec_helper"

RSpec.describe "Registry parent chain lookup" do
  let(:animal) do
    Aver.domain("Animal") do
      action :feed
      query :weight, returns: Integer
      assertion :is_alive
    end
  end

  let(:unregistered) do
    Aver.domain("Unregistered") do
      action :noop
    end
  end

  def make_adapter(d, proto_name = "unit")
    p = Aver.unit(name: proto_name) { nil }
    handlers = {}
    d.markers.each_key { |name| handlers[name] = ->(ctx, payload) { nil } }
    Aver::Adapter.new(domain: d, protocol: p, handlers: handlers)
  end

  before(:each) { Aver.configuration.reset! }

  it "exact match returns adapter" do
    adapter = make_adapter(animal)
    Aver.configuration.adapters << adapter
    found = Aver.configuration.find_adapters(animal)
    expect(found.length).to eq(1)
    expect(found[0]).to equal(adapter)
  end

  it "walks parent when no exact match" do
    child = animal.extend("ChildAnimal") do
      action :pet
    end
    parent_adapter = make_adapter(animal)
    Aver.configuration.adapters << parent_adapter

    found = Aver.configuration.find_adapters(child)
    expect(found.length).to eq(1)
    expect(found[0]).to equal(parent_adapter)
  end

  it "multi-level parent chain" do
    level1 = animal.extend("Level1Animal") do
      action :groom
    end
    level2 = level1.extend("Level2Animal") do
      assertion :is_happy
    end
    grandparent_adapter = make_adapter(animal)
    Aver.configuration.adapters << grandparent_adapter

    found = Aver.configuration.find_adapters(level2)
    expect(found.length).to eq(1)
    expect(found[0]).to equal(grandparent_adapter)
  end

  it "prefers exact match over parent" do
    child = animal.extend("ExactChild") do
      action :play
    end
    parent_adapter = make_adapter(animal)
    child_adapter = make_adapter(child)
    Aver.configuration.adapters << parent_adapter
    Aver.configuration.adapters << child_adapter

    found = Aver.configuration.find_adapters(child)
    expect(found.length).to eq(1)
    expect(found[0]).to equal(child_adapter)
  end

  it "returns empty for unregistered domain" do
    adapter = make_adapter(animal)
    Aver.configuration.adapters << adapter
    found = Aver.configuration.find_adapters(unregistered)
    expect(found).to eq([])
  end

  it "stops at first parent level with matches" do
    level1 = animal.extend("StopLevel1") do
      action :scratch
    end
    level2 = level1.extend("StopLevel2") do
      assertion :is_fed
    end
    grandparent_adapter = make_adapter(animal)
    parent_adapter = make_adapter(level1)
    Aver.configuration.adapters << grandparent_adapter
    Aver.configuration.adapters << parent_adapter

    found = Aver.configuration.find_adapters(level2)
    expect(found.length).to eq(1)
    expect(found[0]).to equal(parent_adapter)
  end
end

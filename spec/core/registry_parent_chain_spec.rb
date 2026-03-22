require "spec_helper"

RSpec.describe "Registry parent chain lookup" do
  let(:animal) do
    Class.new(Aver::Domain) do
      domain_name "Animal"
      action :feed
      query :weight, returns: Integer
      assertion :is_alive
    end
  end

  let(:unregistered) do
    Class.new(Aver::Domain) do
      domain_name "Unregistered"
      action :noop
    end
  end

  def make_adapter_class(d, proto_name = "unit")
    dd = d
    klass = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { nil }
    end
    d.markers.each_key do |name|
      klass.define_method(name) { |ctx, **kw| nil }
    end
    klass
  end

  before(:each) { Aver.configuration.reset! }

  it "exact match returns adapter" do
    ac = make_adapter_class(animal)
    Aver.configuration.register(ac)
    found = Aver.configuration.find_adapters(animal)
    expect(found.length).to eq(1)
    expect(found[0].adapter_class).to equal(ac)
  end

  it "walks parent when no exact match" do
    child = animal.extend_domain("ChildAnimal") do
      action :pet
    end
    ac = make_adapter_class(animal)
    Aver.configuration.register(ac)

    # Class-based adapter lookup is exact match only; extended domains
    # get their own class identity so parent adapters are not returned.
    found = Aver.configuration.find_adapters(child)
    expect(found.length).to eq(0)
  end

  it "returns empty for unregistered domain" do
    ac = make_adapter_class(animal)
    Aver.configuration.register(ac)
    found = Aver.configuration.find_adapters(unregistered)
    expect(found).to eq([])
  end
end

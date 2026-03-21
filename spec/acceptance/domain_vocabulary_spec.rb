require "spec_helper"

RSpec.describe "Domain vocabulary acceptance" do
  it "captures all marker kinds" do
    d = Aver.domain("vocabulary") do
      action :create
      action :update
      query :get_count, returns: Integer
      query :get_item, payload: Hash, returns: Hash
      assertion :exists
      assertion :is_valid
    end

    expect(d.markers.length).to eq(6)
    kinds = d.markers.values.map(&:kind)
    expect(kinds.count(:action)).to eq(2)
    expect(kinds.count(:query)).to eq(2)
    expect(kinds.count(:assertion)).to eq(2)
  end

  it "markers store metadata" do
    d = Aver.domain("meta-test") do
      action :go, payload: { id: String }
      query :peek, payload: Hash, returns: Array
      assertion :check, payload: { status: String }
    end

    expect(d.markers[:go].payload_type).to eq({ id: String })
    expect(d.markers[:peek].return_type).to eq(Array)
    expect(d.markers[:check].payload_type).to eq({ status: String })
  end

  it "domain name propagates to markers" do
    d = Aver.domain("propagation") do
      action :go
      query :peek, returns: Hash
      assertion :check
    end

    d.markers.each_value do |m|
      expect(m.domain_name).to eq("propagation")
    end
  end

  it "markers report correct kind" do
    d = Aver.domain("vocab-kinds") do
      action :do_thing
      query :get_thing, returns: Hash
      assertion :check_thing
    end

    expect(d.markers[:do_thing].kind).to eq(:action)
    expect(d.markers[:get_thing].kind).to eq(:query)
    expect(d.markers[:check_thing].kind).to eq(:assertion)
  end
end

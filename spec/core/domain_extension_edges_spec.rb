require "spec_helper"

RSpec.describe "Domain extension edge cases" do
  let(:base) do
    Class.new(Aver::Domain) do
      domain_name "EdgeBase"
      action :do_a
      query :get_x, returns: Integer
      assertion :check_a
    end
  end

  it "duplicate query in extension raises" do
    expect {
      base.extend_domain("BadQuery") do
        query :get_x, returns: String
      end
    }.to raise_error(Aver::DomainCollisionError, /collision/)
  end

  it "duplicate assertion in extension raises" do
    expect {
      base.extend_domain("BadAssertion") do
        assertion :check_a
      end
    }.to raise_error(Aver::DomainCollisionError, /collision/)
  end

  it "cross-section different names ok" do
    extended = base.extend_domain("CrossSection") do
      action :do_b
      query :get_y, returns: Integer
      assertion :check_b
    end
    expect(extended.markers.keys).to contain_exactly(:do_a, :get_x, :check_a, :do_b, :get_y, :check_b)
  end
end

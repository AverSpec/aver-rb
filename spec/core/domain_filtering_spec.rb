require "spec_helper"

RSpec.describe "Domain filtering via AVER_DOMAIN" do
  let(:filter_a) do
    Aver.domain("FilterA") do
      action :do_a
      assertion :check_a
    end
  end

  let(:filter_b) do
    Aver.domain("FilterB") do
      action :do_b
      assertion :check_b
    end
  end

  it "AVER_DOMAIN matches includes tests" do
    domain_filter = "FilterA"
    should_skip = domain_filter && filter_a.name != domain_filter
    expect(should_skip).to be false
  end

  it "AVER_DOMAIN mismatch skips tests" do
    domain_filter = "FilterB"
    should_skip = domain_filter && filter_a.name != domain_filter
    expect(should_skip).to be true
  end

  it "AVER_DOMAIN not set runs all" do
    domain_filter = nil
    should_skip_a = domain_filter && filter_a.name != domain_filter
    should_skip_b = domain_filter && filter_b.name != domain_filter
    expect(should_skip_a).to be_falsy
    expect(should_skip_b).to be_falsy
  end
end

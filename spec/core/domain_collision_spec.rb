require "spec_helper"

RSpec.describe "Domain collision detection" do
  it "raises on duplicate name across action and query" do
    expect {
      Aver.domain("collider") do
        action :go
        query :go, returns: String
      end
    }.to raise_error(Aver::DomainCollisionError, /go.*action.*query/)
  end

  it "raises on duplicate name across action and assertion" do
    expect {
      Aver.domain("collider") do
        action :check
        assertion :check
      end
    }.to raise_error(Aver::DomainCollisionError, /check.*action.*assertion/)
  end

  it "reports multiple collisions in one error" do
    expect {
      Aver.domain("collider") do
        action :go
        query :go, returns: String
        action :check
        assertion :check
      end
    }.to raise_error(Aver::DomainCollisionError) { |e|
      expect(e.message).to include("go")
      expect(e.message).to include("check")
    }
  end

  it "allows same name within same section (last wins)" do
    # Re-defining within same section is allowed (just overwrites)
    domain = Aver.domain("ok") do
      action :go
      action :go  # same section, no collision
    end
    expect(domain.markers[:go].kind).to eq(:action)
  end

  it "detects collisions in extended domains" do
    parent = Aver.domain("base") { action :login }
    expect {
      parent.extend("child") do
        query :login, returns: Hash
      end
    }.to raise_error(Aver::DomainCollisionError, /login/)
  end
end

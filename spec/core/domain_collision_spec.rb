require "spec_helper"

RSpec.describe "Domain collision detection" do
  it "raises on duplicate name across action and query" do
    expect {
      Class.new(Aver::Domain) do
        domain_name "collider"
        action :go
        query :go, returns: String
      end
    }.to raise_error(Aver::DomainCollisionError, /go.*action.*query/)
  end

  it "raises on duplicate name across action and assertion" do
    expect {
      Class.new(Aver::Domain) do
        domain_name "collider"
        action :check
        assertion :check
      end
    }.to raise_error(Aver::DomainCollisionError, /check.*action.*assertion/)
  end

  it "raises on first collision encountered" do
    expect {
      Class.new(Aver::Domain) do
        domain_name "collider"
        action :go
        query :go, returns: String
      end
    }.to raise_error(Aver::DomainCollisionError, /go/)
  end

  it "allows same name within same section (last wins)" do
    domain = Class.new(Aver::Domain) do
      domain_name "ok"
      action :go
      action :go  # same section, no collision
    end
    expect(domain.markers[:go].kind).to eq(:action)
  end

  it "detects collisions in extended domains" do
    parent = Class.new(Aver::Domain) do
      domain_name "base"
      action :login
    end
    expect {
      parent.extend_domain("child") do
        query :login, returns: Hash
      end
    }.to raise_error(Aver::DomainCollisionError, /login/)
  end
end

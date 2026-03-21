require "spec_helper"

RSpec.describe "Extensions acceptance" do
  it "extended domain works end-to-end through context" do
    base = Aver.domain("AuthBase") do
      action :login
      assertion :is_logged_in
    end

    extended = base.extend("AdminAuth") do
      action :grant_admin
      assertion :is_admin
    end

    p = Aver.unit { { user: nil, admin: false } }
    a = Aver.implement(extended, protocol: p) do
      handle(:login) { |ctx, payload| ctx[:user] = payload[:username] }
      handle(:is_logged_in) { |ctx, payload| raise "not logged in" unless ctx[:user] }
      handle(:grant_admin) { |ctx, payload| ctx[:admin] = true }
      handle(:is_admin) { |ctx, payload| raise "not admin" unless ctx[:admin] }
    end

    ctx = Aver::Context.new(domain: extended, adapter: a, protocol_ctx: p.setup)
    ctx.given.login(username: "alice")
    ctx.then.is_logged_in
    ctx.when.grant_admin
    ctx.then.is_admin

    trace = ctx.trace
    expect(trace.length).to eq(4)
    expect(trace.map(&:status)).to all(eq("pass"))
  end

  it "extended domain registered via parent adapter in config" do
    base = Aver.domain("ConfigBase") do
      action :go
      assertion :check
    end
    child = base.extend("ConfigChild") do
      action :extra
    end

    p = Aver.unit { {} }
    parent_adapter = Aver.implement(base, protocol: p) do
      handle(:go) { |ctx, payload| nil }
      handle(:check) { |ctx, payload| nil }
    end

    Aver.configuration.reset!
    Aver.configuration.adapters << parent_adapter

    found = Aver.configuration.find_adapters(child)
    expect(found.length).to eq(1)
    expect(found[0]).to equal(parent_adapter)
  end

  it "extension tracks parent domain" do
    parent = Aver.domain("ExtParentTrack") do
      action :base_op
    end

    child = parent.extend("ExtChildTrack") do
      action :extra
    end

    expect(child.parent).to eq(parent)
    expect(child.parent.name).to eq("ExtParentTrack")
  end
end

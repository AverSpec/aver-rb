require "spec_helper"

RSpec.describe "Domain extensions" do
  let(:parent) do
    Aver.domain("Base") do
      action :do_a
      assertion :check_a
    end
  end

  it "inherits parent markers" do
    child = parent.extend("Extended") do
      assertion :check_b
    end
    expect(child.markers.keys).to contain_exactly(:do_a, :check_a, :check_b)
    expect(child.name).to eq("Extended")
  end

  it "tracks parent reference" do
    child = parent.extend("Child") do
      action :do_b
    end
    expect(child.parent).to eq(parent)
  end

  it "duplicate marker raises" do
    expect {
      parent.extend("Bad") do
        action :do_a
      end
    }.to raise_error(Aver::DomainCollisionError, /collision/)
  end

  it "can be implemented" do
    extended = parent.extend("ExtImpl") do
      assertion :is_visible
    end
    p = Aver.unit { {} }
    a = Aver.implement(extended, protocol: p) do
      handle(:do_a) { |ctx, payload| nil }
      handle(:check_a) { |ctx, payload| nil }
      handle(:is_visible) { |ctx, payload| nil }
    end
    expect(a).to be_a(Aver::Adapter)
  end

  it "works in context" do
    extended = parent.extend("ExtCtx") do
      assertion :is_visible
    end
    p = Aver.unit { {} }
    a = Aver.implement(extended, protocol: p) do
      handle(:do_a) { |ctx, payload| nil }
      handle(:check_a) { |ctx, payload| nil }
      handle(:is_visible) { |ctx, payload| nil }
    end
    ctx = Aver::Context.new(domain: extended, adapter: a, protocol_ctx: p.setup)
    ctx.when.do_a
    ctx.then.check_a
    ctx.then.is_visible
    expect(ctx.trace.length).to eq(3)
  end

  it "is itself a Domain" do
    extended = parent.extend("IsDomain") do
      assertion :extra
    end
    expect(extended).to be_a(Aver::Domain)
  end

  it "does not modify the parent" do
    parent.extend("Isolated") do
      action :logout
    end
    expect(parent.markers.keys).to contain_exactly(:do_a, :check_a)
  end

  it "chained extension" do
    level1 = parent.extend("Level1") do
      query :get_x, returns: Integer
    end
    level2 = level1.extend("Level2") do
      assertion :check_x
    end

    expect(level2.markers.keys).to contain_exactly(:do_a, :check_a, :get_x, :check_x)
    expect(level2.parent).to eq(level1)
  end
end

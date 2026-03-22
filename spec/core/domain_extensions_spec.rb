require "spec_helper"

RSpec.describe "Domain extensions" do
  let(:parent) do
    Class.new(Aver::Domain) do
      domain_name "Base"
      action :do_a
      assertion :check_a
    end
  end

  it "inherits parent markers" do
    child = parent.extend_domain("Extended") do
      assertion :check_b
    end
    expect(child.markers.keys).to contain_exactly(:do_a, :check_a, :check_b)
    expect(child.name).to eq("Extended")
  end

  it "tracks parent reference" do
    child = parent.extend_domain("Child") do
      action :do_b
    end
    expect(child.parent).to eq(parent)
  end

  it "duplicate marker raises" do
    expect {
      parent.extend_domain("Bad") do
        action :do_a
      end
    }.to raise_error(Aver::DomainCollisionError, /collision/)
  end

  it "can be implemented" do
    extended = parent.extend_domain("ExtImpl") do
      assertion :is_visible
    end
    p = Aver.unit { {} }
    d = extended
    a = Class.new(Aver::Adapter) do
      domain d
      protocol :unit, -> { {} }
      define_method(:do_a) { |ctx, **kw| nil }
      define_method(:check_a) { |ctx, **kw| nil }
      define_method(:is_visible) { |ctx, **kw| nil }
    end
    expect { a.validate! }.not_to raise_error
  end

  it "works in context" do
    extended = parent.extend_domain("ExtCtx") do
      assertion :is_visible
    end
    d = extended
    adapter_class = Class.new(Aver::Adapter) do
      domain d
      protocol :unit, -> { {} }
      define_method(:do_a) { |ctx, **kw| nil }
      define_method(:check_a) { |ctx, **kw| nil }
      define_method(:is_visible) { |ctx, **kw| nil }
    end
    proto = Aver::UnitProtocol.new(-> { {} }, name: "unit")
    adapter = adapter_class.new
    ctx = Aver::Context.new(domain: extended, adapter: adapter, protocol_ctx: proto.setup)
    ctx.when.do_a
    ctx.then.check_a
    ctx.then.is_visible
    expect(ctx.trace.length).to eq(3)
  end

  it "is itself a class extending Aver::Domain" do
    extended = parent.extend_domain("IsDomain") do
      assertion :extra
    end
    expect(extended < Aver::Domain).to be true
  end

  it "does not modify the parent" do
    parent.extend_domain("Isolated") do
      action :logout
    end
    expect(parent.markers.keys).to contain_exactly(:do_a, :check_a)
  end

  it "chained extension" do
    level1 = parent.extend_domain("Level1") do
      query :get_x, returns: Integer
    end
    level2 = level1.extend_domain("Level2") do
      assertion :check_x
    end

    expect(level2.markers.keys).to contain_exactly(:do_a, :check_a, :get_x, :check_x)
    expect(level2.parent).to eq(level1)
  end
end

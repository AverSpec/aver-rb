require "spec_helper"

RSpec.describe "Error scenarios acceptance" do
  it "missing marker raises NoMethodError" do
    d = Aver.domain("err-missing") { action :real_action }
    p = Aver.unit { {} }
    a = Aver.implement(d, protocol: p) do
      handle(:real_action) { |ctx, payload| nil }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)

    expect { ctx.when.nonexistent_marker }.to raise_error(NoMethodError, /no marker 'nonexistent_marker'/)
  end

  it "wrong proxy kind raises TypeError" do
    d = Aver.domain("err-proxy") do
      action :do_thing
      assertion :verify_thing
    end
    p = Aver.unit { {} }
    a = Aver.implement(d, protocol: p) do
      handle(:do_thing) { |ctx, payload| nil }
      handle(:verify_thing) { |ctx, payload| nil }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: p.setup)

    expect { ctx.when.verify_thing }.to raise_error(TypeError, /assertion.*ctx\.when.*only accepts/)
    expect { ctx.then.do_thing }.to raise_error(TypeError, /action.*ctx\.then.*only accepts/)
    expect { ctx.query.do_thing }.to raise_error(TypeError, /action.*ctx\.query.*only accepts/)
  end

  it "incomplete adapter raises AdapterError" do
    d = Aver.domain("err-incomplete") do
      action :handle_this
      action :handle_that
      query :fetch_status, returns: String
      assertion :status_is_ok
    end
    p = Aver.unit { {} }

    expect {
      Aver.implement(d, protocol: p) do
        handle(:handle_this) { |ctx, payload| nil }
        handle(:status_is_ok) { |ctx, payload| nil }
      end
    }.to raise_error(Aver::AdapterError, /Missing handlers/)
  end

  it "extra handlers raise AdapterError" do
    d = Aver.domain("err-extra") { action :go }
    p = Aver.unit { {} }

    expect {
      Aver.implement(d, protocol: p) do
        handle(:go) { |ctx, payload| nil }
        handle(:bogus) { |ctx, payload| nil }
      end
    }.to raise_error(Aver::AdapterError, /Extra handlers.*bogus/)
  end
end

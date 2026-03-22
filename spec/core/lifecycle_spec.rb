require "spec_helper"

RSpec.describe "Lifecycle hooks" do
  let(:lifecycle_domain) do
    Class.new(Aver::Domain) do
      domain_name "Lifecycle"
      action :do_thing
      assertion :check
    end
  end

  let(:lifecycle_proto) do
    Class.new(Aver::Protocol) do
      attr_accessor :calls, :last_start_meta, :last_end_meta, :last_fail_meta, :fail_attachments

      define_method(:initialize) do
        super(name: "lifecycle")
        @calls = []
        @last_start_meta = nil
        @last_end_meta = nil
        @last_fail_meta = nil
        @fail_attachments = []
      end

      define_method(:setup) { { log: @calls } }

      define_method(:teardown) { |ctx| @calls << "teardown" }

      define_method(:on_test_start) do |ctx, meta|
        @calls << "on_test_start"
        @last_start_meta = meta
      end

      define_method(:on_test_end) do |ctx, meta|
        @calls << "on_test_end"
        @last_end_meta = meta
      end

      define_method(:on_test_fail) do |ctx, meta|
        @calls << "on_test_fail"
        @last_fail_meta = meta
        @fail_attachments
      end
    end.new
  end

  def make_adapter(proto)
    d = lifecycle_domain
    klass = Class.new(Aver::Adapter) do
      domain d
      protocol :unit, -> { { log: [] } }
      define_method(:do_thing) { |ctx, **kw| ctx[:log] << "do_thing" }
      define_method(:check) { |ctx| ctx[:log] << "check" }
    end
    klass.new
  end

  it "on_test_start called with metadata" do
    proto = lifecycle_proto
    adapter = make_adapter(proto)
    protocol_ctx = proto.setup

    meta = Aver::TestMetadata.new(
      test_name: "test_example",
      domain_name: "Lifecycle",
      adapter_name: "lifecycle"
    )
    proto.on_test_start(protocol_ctx, meta)

    expect(proto.calls).to include("on_test_start")
    expect(proto.last_start_meta).to eq(meta)
    expect(proto.last_start_meta.test_name).to eq("test_example")
    expect(proto.last_start_meta.domain_name).to eq("Lifecycle")
  end

  it "on_test_end called on pass" do
    proto = lifecycle_proto
    adapter = make_adapter(proto)
    protocol_ctx = proto.setup

    completion = Aver::TestCompletion.new(
      test_name: "test_pass",
      domain_name: "Lifecycle",
      adapter_name: "lifecycle",
      status: "pass"
    )
    proto.on_test_end(protocol_ctx, completion)

    expect(proto.calls).to include("on_test_end")
    expect(proto.last_end_meta.status).to eq("pass")
  end

  it "on_test_end called on fail" do
    proto = lifecycle_proto
    adapter = make_adapter(proto)
    protocol_ctx = proto.setup

    completion = Aver::TestCompletion.new(
      test_name: "test_fail",
      domain_name: "Lifecycle",
      adapter_name: "lifecycle",
      status: "fail",
      error: "boom"
    )
    proto.on_test_end(protocol_ctx, completion)

    expect(proto.calls).to include("on_test_end")
    expect(proto.last_end_meta.status).to eq("fail")
    expect(proto.last_end_meta.error).to eq("boom")
  end

  it "on_test_fail returns attachments" do
    proto = lifecycle_proto
    proto.fail_attachments = [
      Aver::Attachment.new(name: "screenshot", path: "/tmp/shot.png", mime: "image/png")
    ]
    adapter = make_adapter(proto)
    protocol_ctx = proto.setup

    completion = Aver::TestCompletion.new(
      test_name: "test_artifacts",
      domain_name: "Lifecycle",
      adapter_name: "lifecycle",
      status: "fail",
      error: "assertion failed"
    )
    attachments = proto.on_test_fail(protocol_ctx, completion)

    expect(attachments.length).to eq(1)
    expect(attachments[0].name).to eq("screenshot")
    expect(attachments[0].path).to eq("/tmp/shot.png")
    expect(attachments[0].mime).to eq("image/png")
  end

  it "lifecycle order on pass" do
    proto = lifecycle_proto
    adapter = make_adapter(proto)
    protocol_ctx = proto.setup
    ctx = Aver::Context.new(domain: lifecycle_domain, adapter: adapter, protocol_ctx: protocol_ctx)

    meta = Aver::TestMetadata.new(
      test_name: "test_order",
      domain_name: "Lifecycle",
      adapter_name: "lifecycle"
    )

    proto.on_test_start(protocol_ctx, meta)
    ctx.when.do_thing
    completion = Aver::TestCompletion.new(
      test_name: "test_order",
      domain_name: "Lifecycle",
      adapter_name: "lifecycle",
      status: "pass",
      trace: ctx.trace
    )
    proto.on_test_end(protocol_ctx, completion)
    proto.teardown(protocol_ctx)

    expect(proto.calls).to eq(["on_test_start", "do_thing", "on_test_end", "teardown"])
  end

  it "lifecycle order on fail" do
    proto = lifecycle_proto
    adapter = make_adapter(proto)
    protocol_ctx = proto.setup

    meta = Aver::TestMetadata.new(
      test_name: "test_fail_order",
      domain_name: "Lifecycle",
      adapter_name: "lifecycle"
    )

    proto.on_test_start(protocol_ctx, meta)
    proto.calls << "body_failed"
    completion = Aver::TestCompletion.new(
      test_name: "test_fail_order",
      domain_name: "Lifecycle",
      adapter_name: "lifecycle",
      status: "fail",
      error: "boom"
    )
    proto.on_test_fail(protocol_ctx, completion)
    proto.on_test_end(protocol_ctx, completion)
    proto.teardown(protocol_ctx)

    expect(proto.calls).to eq([
      "on_test_start", "body_failed",
      "on_test_fail", "on_test_end", "teardown"
    ])
  end
end

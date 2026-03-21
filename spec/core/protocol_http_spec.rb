require "spec_helper"
require "averspec/protocol_http"
require "webrick"
require "json"

RSpec.describe "HTTP Protocol" do
  let(:server) { nil }

  after { @server&.shutdown; @thread&.join(2) }

  def start_server
    @server = WEBrick::HTTPServer.new(
      Port: 0,
      BindAddress: "127.0.0.1",
      Logger: WEBrick::Log.new("/dev/null"),
      AccessLog: []
    )

    echo_servlet = Class.new(WEBrick::HTTPServlet::AbstractServlet) do
      def service(req, res)
        res["Content-Type"] = "application/json"
        body = (req.body && !req.body.empty?) ? JSON.parse(req.body) : nil
        res.body = JSON.generate({
          method: req.request_method,
          path: req.path,
          body: body
        })
      end
    end
    @server.mount("/echo", echo_servlet)
    @thread = Thread.new { @server.start }
    @server[:Port]
  end

  it "creates an HttpProtocol" do
    protocol = Aver.http(base_url: "http://localhost:3000")
    expect(protocol).to be_a(Aver::HttpProtocol)
    expect(protocol.name).to eq("http")
  end

  it "performs GET requests" do
    port = start_server
    ctx = Aver::HttpContext.new(base_url: "http://127.0.0.1:#{port}")
    response = ctx.get("/echo")
    data = JSON.parse(response.body)
    expect(data["method"]).to eq("GET")
  end

  it "performs POST requests with body" do
    port = start_server
    ctx = Aver::HttpContext.new(base_url: "http://127.0.0.1:#{port}")
    response = ctx.post("/echo", { title: "test" })
    data = JSON.parse(response.body)
    expect(data["method"]).to eq("POST")
    expect(data["body"]["title"]).to eq("test")
  end

  it "performs PUT requests" do
    port = start_server
    ctx = Aver::HttpContext.new(base_url: "http://127.0.0.1:#{port}")
    response = ctx.put("/echo", { status: "done" })
    data = JSON.parse(response.body)
    expect(data["method"]).to eq("PUT")
  end

  it "performs DELETE requests" do
    port = start_server
    ctx = Aver::HttpContext.new(base_url: "http://127.0.0.1:#{port}")
    response = ctx.delete("/echo")
    expect(response.code.to_i).to eq(200)
  end

  it "protocol setup and teardown lifecycle" do
    port = start_server
    protocol = Aver::HttpProtocol.new(base_url: "http://127.0.0.1:#{port}")
    ctx = protocol.setup
    expect(ctx).to be_a(Aver::HttpContext)
    expect { protocol.teardown(ctx) }.not_to raise_error
  end
end

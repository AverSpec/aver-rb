require "spec_helper"
require "net/http"
require "json"

RSpec.describe Aver::OtlpReceiver do
  let(:receiver) { Aver.create_otlp_receiver }

  after { receiver.stop }

  it "starts on a random port" do
    port = receiver.start
    expect(port).to be > 0
  end

  it "accepts OTLP JSON traces" do
    port = receiver.start
    body = {
      "resourceSpans" => [{
        "scopeSpans" => [{
          "spans" => [{
            "traceId" => "abc123",
            "spanId" => "span1",
            "name" => "task.create",
            "attributes" => [
              { "key" => "task.title", "value" => { "stringValue" => "test" } }
            ]
          }]
        }]
      }]
    }

    uri = URI("http://127.0.0.1:#{port}/v1/traces")
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req.body = JSON.generate(body)
    response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }

    expect(response.code).to eq("200")
    spans = receiver.get_spans
    expect(spans.length).to eq(1)
    expect(spans[0].name).to eq("task.create")
    expect(spans[0].attributes["task.title"]).to eq("test")
  end

  it "rejects protobuf content type with 415" do
    port = receiver.start
    uri = URI("http://127.0.0.1:#{port}/v1/traces")
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/x-protobuf"
    req.body = "binary"
    response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
    expect(response.code).to eq("415")
  end

  it "resets collected spans" do
    port = receiver.start
    body = {
      "resourceSpans" => [{
        "scopeSpans" => [{
          "spans" => [{ "traceId" => "t", "spanId" => "s", "name" => "op" }]
        }]
      }]
    }
    uri = URI("http://127.0.0.1:#{port}/v1/traces")
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req.body = JSON.generate(body)
    Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }

    expect(receiver.get_spans.length).to eq(1)
    receiver.reset
    expect(receiver.get_spans.length).to eq(0)
  end

  it "parses integer and boolean attributes" do
    receiver.ingest({
      "resourceSpans" => [{
        "scopeSpans" => [{
          "spans" => [{
            "traceId" => "t", "spanId" => "s", "name" => "op",
            "attributes" => [
              { "key" => "count", "value" => { "intValue" => "42" } },
              { "key" => "ok", "value" => { "boolValue" => true } },
              { "key" => "rate", "value" => { "doubleValue" => 0.95 } }
            ]
          }]
        }]
      }]
    })
    span = receiver.get_spans[0]
    expect(span.attributes["count"]).to eq(42)
    expect(span.attributes["ok"]).to eq(true)
    expect(span.attributes["rate"]).to eq(0.95)
  end

  it "parses span links" do
    receiver.ingest({
      "resourceSpans" => [{
        "scopeSpans" => [{
          "spans" => [{
            "traceId" => "t1", "spanId" => "s1", "name" => "op",
            "links" => [
              { "spanContext" => { "traceId" => "t2", "spanId" => "s2" } }
            ]
          }]
        }]
      }]
    })
    span = receiver.get_spans[0]
    expect(span.links.length).to eq(1)
    expect(span.links[0].trace_id).to eq("t2")
    expect(span.links[0].span_id).to eq("s2")
  end

  it "respects max_spans limit" do
    small_receiver = Aver.create_otlp_receiver(max_spans: 2)
    spans = (1..5).map { |i| { "traceId" => "t", "spanId" => "s#{i}", "name" => "op#{i}" } }
    small_receiver.ingest({
      "resourceSpans" => [{ "scopeSpans" => [{ "spans" => spans }] }]
    })
    expect(small_receiver.get_spans.length).to eq(2)
  end

  it "normalizes empty parentSpanId to nil" do
    receiver.ingest({
      "resourceSpans" => [{
        "scopeSpans" => [{
          "spans" => [{
            "traceId" => "t", "spanId" => "s", "name" => "root",
            "parentSpanId" => ""
          }]
        }]
      }]
    })
    expect(receiver.get_spans[0].parent_span_id).to be_nil
  end
end

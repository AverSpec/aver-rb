require "webrick"
require "json"

module Aver
  DEFAULT_MAX_SPANS = 10_000

  class OtlpReceiver
    attr_reader :port

    def initialize(max_spans: DEFAULT_MAX_SPANS)
      @max_spans = max_spans
      @spans = []
      @mutex = Mutex.new
      @server = nil
      @thread = nil
      @port = 0
      @limit_warned = false
    end

    def get_spans
      @mutex.synchronize { @spans.dup }
    end

    def reset
      @mutex.synchronize do
        @spans.clear
        @limit_warned = false
      end
    end

    def ingest(body)
      @mutex.synchronize do
        (body["resourceSpans"] || []).each do |rs|
          (rs["scopeSpans"] || []).each do |ss|
            (ss["spans"] || []).each do |span|
              if @spans.length >= @max_spans
                @limit_warned = true unless @limit_warned
                return
              end

              parent_span_id = span["parentSpanId"]
              if parent_span_id == "" || parent_span_id == "0000000000000000"
                parent_span_id = nil
              end

              raw_links = span["links"] || []
              links = raw_links.map do |link|
                sc = link["spanContext"] || {}
                SpanLink.new(
                  trace_id: sc["traceId"] || link["traceId"] || "",
                  span_id: sc["spanId"] || link["spanId"] || ""
                )
              end

              attributes = _parse_attributes(span["attributes"] || [])

              @spans << CollectedSpan.new(
                trace_id: span["traceId"] || "",
                span_id: span["spanId"] || "",
                name: span["name"] || "",
                attributes: attributes,
                parent_span_id: parent_span_id,
                links: links
              )
            end
          end
        end
      end
    end

    def start
      @server = WEBrick::HTTPServer.new(
        Port: 0,
        BindAddress: "127.0.0.1",
        Logger: WEBrick::Log.new("/dev/null"),
        AccessLog: []
      )
      @port = @server[:Port]

      receiver = self
      @server.mount_proc("/v1/traces") do |req, res|
        if req.request_method != "POST"
          res.status = 405
          res["Content-Type"] = "application/json"
          res.body = '{"error":"Method not allowed"}'
          next
        end

        content_type = req["Content-Type"] || ""
        if content_type.include?("application/x-protobuf") || content_type.include?("application/grpc")
          res.status = 415
          res["Content-Type"] = "application/json"
          res.body = JSON.generate({
            error: "Unsupported content-type \"#{content_type}\". The Aver OTLP receiver only accepts JSON. Configure your exporter to use OTLP/HTTP JSON (application/json)."
          })
          next
        end

        begin
          body = JSON.parse(req.body || "{}")
        rescue JSON::ParserError
          res.status = 400
          res["Content-Type"] = "application/json"
          res.body = '{"error":"Invalid JSON body"}'
          next
        end

        receiver.ingest(body)
        res.status = 200
        res["Content-Type"] = "application/json"
        res.body = "{}"
      end

      @thread = Thread.new { @server.start }
      @port
    end

    def stop
      @server&.shutdown
      @thread&.join(5)
      @server = nil
      @thread = nil
    end

    private

    def _parse_attributes(attrs)
      result = {}
      attrs.each do |attr|
        key = attr["key"] || ""
        value = attr["value"] || {}
        if value.key?("stringValue")
          result[key] = value["stringValue"]
        elsif value.key?("intValue")
          result[key] = value["intValue"].to_i
        elsif value.key?("doubleValue")
          result[key] = value["doubleValue"].to_f
        elsif value.key?("boolValue")
          result[key] = value["boolValue"]
        else
          result[key] = value.to_s
        end
      end
      result
    end
  end

  def self.create_otlp_receiver(max_spans: DEFAULT_MAX_SPANS)
    OtlpReceiver.new(max_spans: max_spans)
  end
end

require "net/http"
require "uri"
require "json"

module Aver
  class HttpContext
    def initialize(base_url:, timeout: 30, default_headers: {}, debug: false)
      @base_url = base_url.chomp("/")
      @timeout = timeout
      @default_headers = default_headers
      @debug = debug
    end

    def get(path)
      _request("GET", path)
    end

    def post(path, body = nil)
      _request("POST", path, body)
    end

    def put(path, body = nil)
      _request("PUT", path, body)
    end

    def patch(path, body = nil)
      _request("PATCH", path, body)
    end

    def delete(path)
      _request("DELETE", path)
    end

    private

    def _request(method, path, body = nil)
      uri = URI.parse("#{@base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      req = case method
            when "GET" then Net::HTTP::Get.new(uri.request_uri)
            when "POST" then Net::HTTP::Post.new(uri.request_uri)
            when "PUT" then Net::HTTP::Put.new(uri.request_uri)
            when "PATCH" then Net::HTTP::Patch.new(uri.request_uri)
            when "DELETE" then Net::HTTP::Delete.new(uri.request_uri)
            end

      @default_headers.each { |k, v| req[k] = v }

      if body
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(body)
      end

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = http.request(req)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

      if @debug
        $stderr.puts "[aver-http] #{method} #{path} -> #{response.code} (#{(elapsed * 1000).round(1)}ms)"
      end

      response
    end
  end

  class HttpProtocol < Protocol
    def initialize(base_url:, timeout: 30, default_headers: {}, debug: false)
      super(name: "http")
      @base_url = base_url
      @timeout = timeout
      @default_headers = default_headers
      @debug = debug
    end

    def setup
      HttpContext.new(
        base_url: @base_url,
        timeout: @timeout,
        default_headers: @default_headers,
        debug: @debug
      )
    end

    def teardown(ctx)
      # no-op for net/http (no persistent connection pool)
    end
  end

  def self.http(base_url:, timeout: 30, default_headers: {}, debug: false)
    HttpProtocol.new(
      base_url: base_url,
      timeout: timeout,
      default_headers: default_headers,
      debug: debug
    )
  end
end

module Aver
  class TraceEntry
    attr_accessor :kind, :category, :name, :payload, :status, :duration_ms, :result, :error, :telemetry

    def initialize(kind:, category:, name:, payload: nil, status: "pass", duration_ms: 0.0, result: nil, error: nil, telemetry: nil)
      @kind = kind
      @category = category
      @name = name
      @payload = payload
      @status = status
      @duration_ms = duration_ms
      @result = result
      @error = error
      @telemetry = telemetry
    end
  end
end

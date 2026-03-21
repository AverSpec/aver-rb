module Aver
  class Marker
    attr_accessor :kind, :name, :domain_name, :payload_type, :return_type, :telemetry

    def initialize(kind:, payload_type: nil, return_type: nil, telemetry: nil)
      @kind = kind
      @payload_type = payload_type
      @return_type = return_type
      @telemetry = telemetry
    end
  end
end

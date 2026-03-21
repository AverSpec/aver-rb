require "set"

require_relative "averspec/version"
require_relative "averspec/marker"
require_relative "averspec/domain"
require_relative "averspec/protocol"
require_relative "averspec/trace"
require_relative "averspec/telemetry_types"
require_relative "averspec/telemetry_mode"
require_relative "averspec/proxy"
require_relative "averspec/context"
require_relative "averspec/adapter"
require_relative "averspec/suite"
require_relative "averspec/config"
require_relative "averspec/eventually"
require_relative "averspec/trace_format"
require_relative "averspec/composed"
require_relative "averspec/approvals"
require_relative "averspec/correlation"
require_relative "averspec/telemetry_contract"
require_relative "averspec/telemetry_verify"
require_relative "averspec/otlp_receiver"

module Aver
  # Top-level API methods defined in individual files

  # Lazy-load protocol_http to avoid net/http overhead unless needed
  def self.http(**kwargs)
    require_relative "averspec/protocol_http"
    HttpProtocol.new(**kwargs)
  end
end

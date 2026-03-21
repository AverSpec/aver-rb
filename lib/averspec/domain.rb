module Aver
  class Domain
    attr_reader :name, :markers

    def initialize(name, &block)
      @name = name
      @markers = {}
      @parent = nil
      instance_eval(&block) if block
    end

    def action(name, payload: nil, telemetry: nil)
      marker = Marker.new(kind: :action, payload_type: payload, telemetry: telemetry)
      marker.name = name
      marker.domain_name = @name
      @markers[name] = marker
    end

    def query(name, payload: nil, returns: nil, telemetry: nil)
      marker = Marker.new(kind: :query, payload_type: payload, return_type: returns, telemetry: telemetry)
      marker.name = name
      marker.domain_name = @name
      @markers[name] = marker
    end

    def assertion(name, payload: nil, telemetry: nil)
      marker = Marker.new(kind: :assertion, payload_type: payload, telemetry: telemetry)
      marker.name = name
      marker.domain_name = @name
      @markers[name] = marker
    end

    def extend(new_name, &block)
      child = Domain.new(new_name)
      @markers.each { |k, v| child.markers[k] = v }
      child.instance_variable_set(:@parent, self)
      child.instance_eval(&block) if block
      child
    end

    def parent
      @parent
    end
  end

  def self.domain(name, &block)
    Domain.new(name, &block)
  end
end

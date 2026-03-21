module Aver
  class DomainCollisionError < StandardError; end

  class Domain
    attr_reader :name, :markers

    def initialize(name, &block)
      @name = name
      @markers = {}
      @parent = nil
      @pending_markers = []
      if block
        instance_eval(&block)
        _check_collisions
      end
    end

    def action(name, payload: nil, telemetry: nil)
      marker = Marker.new(kind: :action, payload_type: payload, telemetry: telemetry)
      marker.name = name
      marker.domain_name = @name
      @pending_markers << { name: name, section: :action }
      @markers[name] = marker
    end

    def query(name, payload: nil, returns: nil, telemetry: nil)
      marker = Marker.new(kind: :query, payload_type: payload, return_type: returns, telemetry: telemetry)
      marker.name = name
      marker.domain_name = @name
      @pending_markers << { name: name, section: :query }
      @markers[name] = marker
    end

    def assertion(name, payload: nil, telemetry: nil)
      marker = Marker.new(kind: :assertion, payload_type: payload, telemetry: telemetry)
      marker.name = name
      marker.domain_name = @name
      @pending_markers << { name: name, section: :assertion }
      @markers[name] = marker
    end

    def extend(new_name, &block)
      child = Domain.new(new_name)
      @markers.each do |k, v|
        child.markers[k] = v
        child.instance_variable_get(:@pending_markers) << { name: k, section: v.kind }
      end
      child.instance_variable_set(:@parent, self)
      if block
        child.instance_eval(&block)
        child.send(:_check_collisions)
      end
      child
    end

    def parent
      @parent
    end

    private

    def _check_collisions
      seen = {}
      collisions = []

      @pending_markers.each do |entry|
        marker_name = entry[:name]
        section = entry[:section]
        if seen.key?(marker_name) && seen[marker_name] != section
          collisions << "#{marker_name} (defined in both #{seen[marker_name]} and #{section})"
        end
        seen[marker_name] = section
      end

      if collisions.any?
        raise DomainCollisionError, "Domain '#{@name}' has marker collisions: #{collisions.join('; ')}"
      end
    end
  end

  def self.domain(name, &block)
    Domain.new(name, &block)
  end
end

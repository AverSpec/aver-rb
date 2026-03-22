require "set"

module Aver
  class DomainCollisionError < StandardError; end

  class Domain
    class << self
      def domain_name(name = nil)
        if name
          @domain_name = name
        else
          @domain_name || _default_domain_name
        end
      end

      def action(name, payload: nil, telemetry: nil)
        _check_collision_inline(name, :action)
        marker = Marker.new(kind: :action, payload_type: payload, telemetry: telemetry)
        marker.name = name
        marker.domain_name = domain_name
        _pending_markers << { name: name, section: :action }
        markers[name] = marker
      end

      def query(name, payload: nil, returns: nil, telemetry: nil)
        _check_collision_inline(name, :query)
        marker = Marker.new(kind: :query, payload_type: payload, return_type: returns, telemetry: telemetry)
        marker.name = name
        marker.domain_name = domain_name
        _pending_markers << { name: name, section: :query }
        markers[name] = marker
      end

      def assertion(name, payload: nil, telemetry: nil)
        _check_collision_inline(name, :assertion)
        marker = Marker.new(kind: :assertion, payload_type: payload, telemetry: telemetry)
        marker.name = name
        marker.domain_name = domain_name
        _pending_markers << { name: name, section: :assertion }
        markers[name] = marker
      end

      def markers
        @markers ||= {}
      end

      def name
        domain_name
      end

      def parent
        @parent
      end

      def extend_domain(new_name, &block)
        child = Class.new(Aver::Domain)
        child.domain_name(new_name)

        # Copy parent markers into child
        markers.each do |k, v|
          child.markers[k] = v
          child._pending_markers << { name: k, section: v.kind }
          child._inherited_marker_names.add(k)
        end
        child.instance_variable_set(:@parent, self)

        if block
          child.class_eval(&block)
          child.send(:_check_collisions)
        end
        child
      end

      # For internal use by extend_domain
      def _pending_markers
        @_pending_markers ||= []
      end

      def _inherited_marker_names
        @_inherited_marker_names ||= Set.new
      end

      def inherited(subclass)
        super
        # Don't propagate markers to subclasses automatically;
        # each subclass defines its own markers via class macros.
      end

      private

      def _check_collision_inline(marker_name, section)
        existing = markers[marker_name]
        return unless existing
        return if existing.kind == section # same section, allow overwrite
        # Cross-section collision or inherited marker collision
        if _inherited_marker_names.include?(marker_name)
          raise DomainCollisionError, "Domain '#{domain_name}' has marker collisions: #{marker_name} (defined in both #{existing.kind} and #{section})"
        else
          raise DomainCollisionError, "Domain '#{domain_name}' has marker collisions: #{marker_name} (defined in both #{existing.kind} and #{section})"
        end
      end

      def _default_domain_name
        return nil unless self.to_s && !self.to_s.empty?
        base = self.to_s.split("::").last
        return nil if base.nil? || base.empty?
        base.gsub(/([a-z0-9])([A-Z])/, '\1-\2').downcase
      end

      def _check_collisions
        seen = {}
        collisions = []

        _pending_markers.each do |entry|
          marker_name = entry[:name]
          section = entry[:section]
          if seen.key?(marker_name)
            prev_section = seen[marker_name]
            if prev_section != section
              collisions << "#{marker_name} (defined in both #{prev_section} and #{section})"
            elsif _inherited_marker_names.include?(marker_name)
              collisions << "#{marker_name} (duplicate in #{section})"
            end
          end
          seen[marker_name] = section
        end

        if collisions.any?
          raise DomainCollisionError, "Domain '#{domain_name}' has marker collisions: #{collisions.join('; ')}"
        end
      end
    end
  end

end

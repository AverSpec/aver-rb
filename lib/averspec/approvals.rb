require "json"
require "fileutils"

module Aver
  class ApprovalError < StandardError; end

  module Approvals
    def self.approve(value, name: "approval", scrub: nil, test_name: nil, file_path: nil)
      auto_approve = ENV["AVER_APPROVE"] == "1"

      # Determine caller info if not provided
      if file_path.nil? || test_name.nil?
        caller_loc = caller_locations(1, 10)
        frame = caller_loc.find { |f| f.label&.match?(/test_|spec|aver_test|block/) } || caller_loc[0]
        file_path ||= frame.path
        test_name ||= frame.label
      end

      # Serialize
      text, ext = _serialize(value)

      # Apply scrubbers
      text = _apply_scrubbers(text, scrub)

      # Build paths
      safe_test = _safe_name(test_name)
      base_dir = File.join(File.dirname(file_path), "__approvals__", safe_test)
      FileUtils.mkdir_p(base_dir)

      safe = _safe_name(name)
      approved_path = File.join(base_dir, "#{safe}.approved.#{ext}")
      received_path = File.join(base_dir, "#{safe}.received.#{ext}")
      diff_path = File.join(base_dir, "#{safe}.diff.txt")

      unless File.exist?(approved_path)
        if auto_approve
          File.write(approved_path, text)
          _cleanup(received_path, diff_path)
          return
        end
        raise ApprovalError, "No approved baseline at #{approved_path}. Run with AVER_APPROVE=1 to create it."
      end

      approved_text = File.read(approved_path)

      if text == approved_text
        _cleanup(received_path, diff_path)
        return
      end

      # Mismatch
      if auto_approve
        File.write(approved_path, text)
        _cleanup(received_path, diff_path)
        return
      end

      File.write(received_path, text)
      diff_text = _diff_text(approved_text, text)
      File.write(diff_path, diff_text)

      raise ApprovalError,
        "Approval mismatch for '#{name}'.\n" \
        "  Approved: #{approved_path}\n" \
        "  Received: #{received_path}\n" \
        "  Diff:     #{diff_path}\n" \
        "Run with AVER_APPROVE=1 to update the baseline."
    end

    def self.characterize(value, **kwargs)
      approve(value, **kwargs)
    end

    private

    def self._safe_name(name)
      name.to_s.gsub(/[^\w\-.]/, "_")
    end

    def self._serialize(value)
      case value
      when Hash, Array
        [JSON.pretty_generate(value), "json"]
      when String
        [value, "txt"]
      else
        [value.to_s, "txt"]
      end
    end

    def self._apply_scrubbers(text, scrub)
      return text unless scrub
      scrub.each do |entry|
        pattern = entry[:pattern]
        replacement = entry[:replacement]
        pattern = Regexp.new(pattern) if pattern.is_a?(String)
        text = text.gsub(pattern, replacement)
      end
      text
    end

    def self._diff_text(expected, actual)
      expected_lines = expected.lines
      actual_lines = actual.lines
      # Simple unified diff
      lines = ["--- approved", "+++ received"]
      max = [expected_lines.length, actual_lines.length].max
      max.times do |i|
        exp = expected_lines[i]
        act = actual_lines[i]
        if exp == act
          lines << " #{exp&.chomp}"
        else
          lines << "-#{exp&.chomp}" if exp
          lines << "+#{act&.chomp}" if act
        end
      end
      lines.join("\n")
    end

    def self._cleanup(*paths)
      paths.each { |p| File.delete(p) if File.exist?(p) }
    end
  end

  def self.approve(value, **kwargs)
    Approvals.approve(value, **kwargs)
  end

  def self.characterize(value, **kwargs)
    Approvals.characterize(value, **kwargs)
  end
end

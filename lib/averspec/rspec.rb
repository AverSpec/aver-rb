require "averspec"

module Aver
  module RSpec
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def aver_test(name, &block)
        domain = metadata[:aver]
        adapters = Aver.configuration.find_adapters(domain)

        if adapters.empty?
          registered_names = Aver.configuration.adapters.map { |a| a.domain.name }
          if registered_names.any?
            raise Aver::AdapterError, "No adapters registered for domain '#{domain.name}'. Registered adapters: #{registered_names.inspect}"
          else
            raise Aver::AdapterError, "No adapters registered for domain '#{domain.name}'. Did you add adapters in conftest?"
          end
        end

        # Domain filtering via AVER_DOMAIN env var
        domain_filter = ENV["AVER_DOMAIN"]
        if domain_filter && domain.name != domain_filter
          it "#{name} [skipped: AVER_DOMAIN=#{domain_filter}]" do
            skip "Domain '#{domain.name}' does not match AVER_DOMAIN='#{domain_filter}'"
          end
          return
        end

        adapters.each do |adapter|
          it "#{name} [#{adapter.name}]" do
            protocol_ctx = adapter.protocol.setup
            ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, protocol: adapter.protocol)

            meta = Aver::TestMetadata.new(
              test_name: name,
              domain_name: domain.name,
              adapter_name: adapter.name
            )
            adapter.protocol.on_test_start(protocol_ctx, meta)

            begin
              instance_exec(ctx, &block)

              completion = Aver::TestCompletion.new(
                test_name: name,
                domain_name: domain.name,
                adapter_name: adapter.name,
                status: "pass",
                trace: ctx.trace
              )
              adapter.protocol.on_test_end(protocol_ctx, completion)
            rescue => e
              completion = Aver::TestCompletion.new(
                test_name: name,
                domain_name: domain.name,
                adapter_name: adapter.name,
                status: "fail",
                error: e.message,
                trace: ctx.trace
              )
              adapter.protocol.on_test_fail(protocol_ctx, completion)
              adapter.protocol.on_test_end(protocol_ctx, completion)

              # Error enhancement: append formatted trace
              trace = ctx.trace
              if trace.any?
                trace_text = Aver.format_trace(trace)
                enhanced = "#{e.message}\n\nTest steps:\n#{trace_text}"
                raise e.class, enhanced
              else
                raise
              end
            ensure
              teardown_mode = Aver.configuration.teardown_failure_mode
              begin
                adapter.protocol.teardown(protocol_ctx)
              rescue => teardown_err
                if teardown_mode == :warn
                  warn "Aver teardown error (suppressed): #{teardown_err.message}"
                else
                  raise
                end
              end
            end
          end
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include Aver::RSpec, aver: ->(v) { v.is_a?(Aver::Domain) }
end

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
          registered_names = Aver.configuration.adapter_classes.map { |ac| ac.domain&.name }
          if registered_names.any?
            raise Aver::AdapterError, "No adapters registered for domain '#{domain.name}'. Registered adapters: #{registered_names.inspect}"
          else
            raise Aver::AdapterError, "No adapters registered for domain '#{domain.name}'. Did you add adapters in conftest?"
          end
        end

        # Domain filtering via AVER_DOMAIN env var
        domain_name = domain.respond_to?(:domain_name) ? domain.domain_name : domain.name
        domain_filter = ENV["AVER_DOMAIN"]
        if domain_filter && domain_name != domain_filter
          it "#{name} [skipped: AVER_DOMAIN=#{domain_filter}]" do
            skip "Domain '#{domain_name}' does not match AVER_DOMAIN='#{domain_filter}'"
          end
          return
        end

        adapters.each do |adapter|
          adapter_name = adapter.respond_to?(:name) ? adapter.name : "unknown"
          it "#{name} [#{adapter_name}]" do
            protocol_ctx = adapter.protocol.setup
            ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx, protocol: adapter.protocol)

            meta = Aver::TestMetadata.new(
              test_name: name,
              domain_name: domain_name,
              adapter_name: adapter_name
            )
            adapter.protocol.on_test_start(protocol_ctx, meta)

            begin
              instance_exec(ctx, &block)

              completion = Aver::TestCompletion.new(
                test_name: name,
                domain_name: domain_name,
                adapter_name: adapter_name,
                status: "pass",
                trace: ctx.trace
              )
              adapter.protocol.on_test_end(protocol_ctx, completion)
            rescue => e
              completion = Aver::TestCompletion.new(
                test_name: name,
                domain_name: domain_name,
                adapter_name: adapter_name,
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

  # RSpec integration for class-based domains: `RSpec.describe TaskBoard do`
  module RSpecClassDomain
    def self.included(base)
      base.extend(Aver::RSpec::ClassMethods)

      domain_class = base.metadata[:described_class]
      return unless domain_class.is_a?(Class) && domain_class < Aver::Domain

      adapter_classes = Aver.configuration.instance_variable_get(:@adapter_classes)
        .select { |ac| ac.domain == domain_class }

      return if adapter_classes.empty?

      build_ctx = ->(adapter_class) do
        protocol_obj = if adapter_class.protocol_instance
          adapter_class.protocol_instance
        elsif adapter_class.protocol_factory
          Aver::UnitProtocol.new(adapter_class.protocol_factory, name: adapter_class.protocol_name.to_s)
        else
          raise "No protocol configured for #{adapter_class}"
        end

        protocol_ctx = protocol_obj.setup
        adapter_inst = adapter_class.new
        Aver::Context.new(
          domain: domain_class,
          adapter: adapter_inst,
          protocol_ctx: protocol_ctx,
          protocol: protocol_obj
        )
      end

      if adapter_classes.size == 1
        adapter_class = adapter_classes.first
        base.let(:ctx) { build_ctx.call(adapter_class) }
      else
        adapter_classes.each do |adapter_class|
          proto_name = adapter_class.protocol_name || "unknown"
          base.context "[#{proto_name}]" do
            let(:ctx) { build_ctx.call(adapter_class) }
          end
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include Aver::RSpec, aver: ->(v) {
    v.is_a?(Class) && v < Aver::Domain
  }

  config.include Aver::RSpecClassDomain, described_class: ->(v) {
    v.is_a?(Class) && v < Aver::Domain
  }
end

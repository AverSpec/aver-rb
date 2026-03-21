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

        adapters.each do |adapter|
          it "#{name} [#{adapter.name}]" do
            protocol_ctx = adapter.protocol.setup
            ctx = Aver::Context.new(domain: domain, adapter: adapter, protocol_ctx: protocol_ctx)
            begin
              instance_exec(ctx, &block)
            ensure
              adapter.protocol.teardown(protocol_ctx)
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

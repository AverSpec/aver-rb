require "spec_helper"

class MissingAdapterDomain < Aver::Domain
  domain_name "missing-adapter-test"
  assertion :missing_adapter_error_lists_registered
end

class MissingAdapterAdapter < Aver::Adapter
  domain MissingAdapterDomain
  protocol :unit, -> { {} }

  def missing_adapter_error_lists_registered(state, **kw)
    # Create a config with a known adapter, then look up a missing domain.
    config = Aver::Configuration.new
    known = Class.new(Aver::Domain) do
      domain_name "KnownDomain"
      action :ping
    end
    dd = known
    adapter_class = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:ping) { |ctx, **k| nil }
    end
    config.register(adapter_class)

    missing = Class.new(Aver::Domain) do
      domain_name "NonExistent"
      action :noop
    end
    found = config.find_adapters(missing)
    raise "Expected no adapters, got #{found.length}" unless found.empty?

    # Verify that we can list registered adapter domain names
    registered_names = config.adapter_classes.map { |ac| ac.domain.name }
    raise "Expected 'KnownDomain' in #{registered_names}" unless registered_names.include?("KnownDomain")
  end
end

Aver.register(MissingAdapterAdapter)

RSpec.describe "Missing adapter error acceptance", aver: MissingAdapterDomain do

  aver_test "missing adapter error lists registered adapters" do |ctx|
    ctx.then.missing_adapter_error_lists_registered
  end
end

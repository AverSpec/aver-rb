require "spec_helper"

MissingAdapterDomain = Aver.domain("missing-adapter-test") do
  assertion :missing_adapter_error_lists_registered
end

MissingAdapterAdapter = Aver.implement(MissingAdapterDomain, protocol: Aver.unit { {} }) do
  handle(:missing_adapter_error_lists_registered) do |state, p|
    # Create a config with a known adapter, then look up a missing domain.
    config = Aver::Configuration.new
    known = Aver.domain("KnownDomain") { action :ping }
    proto = Aver.unit { {} }
    adapter = Aver.implement(known, protocol: proto) do
      handle(:ping) { |ctx, payload| nil }
    end
    config.adapters << adapter

    missing = Aver.domain("NonExistent") { action :noop }
    found = config.find_adapters(missing)
    raise "Expected no adapters, got #{found.length}" unless found.empty?

    # Verify that we can list registered adapter domain names
    registered_names = config.adapters.map { |a| a.domain.name }
    raise "Expected 'KnownDomain' in #{registered_names}" unless registered_names.include?("KnownDomain")
  end
end

Aver.configuration.adapters << MissingAdapterAdapter

RSpec.describe "Missing adapter error acceptance", aver: MissingAdapterDomain do

  aver_test "missing adapter error lists registered adapters" do |ctx|
    ctx.then.missing_adapter_error_lists_registered
  end
end

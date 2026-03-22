require "spec_helper"

DomainFilterDomain = Aver.domain("domain-filter-test") do
  action :setup_domain_filter_test
  assertion :filter_skips_non_matching
  assertion :filter_runs_matching
end

DomainFilterAdapter = Aver.implement(DomainFilterDomain, protocol: Aver.unit { {} }) do
  handle(:setup_domain_filter_test) do |state, p|
    state[:d] = Aver.domain("FilterTarget") { action :ping }
    proto = Aver.unit { {} }
    state[:adapter] = Aver.implement(state[:d], protocol: proto) do
      handle(:ping) { |ctx, payload| nil }
    end
  end

  handle(:filter_skips_non_matching) do |state, p|
    old = ENV["AVER_DOMAIN"]
    begin
      ENV["AVER_DOMAIN"] = "SomeOtherDomain"
      d = state[:d]
      # Re-read the env var as the framework would
      filter = ENV["AVER_DOMAIN"]
      unless filter && filter != d.name
        raise "Expected filter to not match domain name '#{d.name}'"
      end
    ensure
      if old
        ENV["AVER_DOMAIN"] = old
      else
        ENV.delete("AVER_DOMAIN")
      end
    end
  end

  handle(:filter_runs_matching) do |state, p|
    old = ENV["AVER_DOMAIN"]
    begin
      d = state[:d]
      ENV["AVER_DOMAIN"] = d.name
      filter = ENV["AVER_DOMAIN"]
      unless filter == d.name
        raise "Expected filter to match domain name '#{d.name}', got '#{filter}'"
      end
    ensure
      if old
        ENV["AVER_DOMAIN"] = old
      else
        ENV.delete("AVER_DOMAIN")
      end
    end
  end
end

Aver.configuration.adapters << DomainFilterAdapter

RSpec.describe "Domain filter acceptance", aver: DomainFilterDomain do

  aver_test "AVER_DOMAIN filter skips non-matching domain" do |ctx|
    ctx.given.setup_domain_filter_test
    ctx.then.filter_skips_non_matching
  end

  aver_test "AVER_DOMAIN filter runs matching domain" do |ctx|
    ctx.given.setup_domain_filter_test
    ctx.then.filter_runs_matching
  end
end

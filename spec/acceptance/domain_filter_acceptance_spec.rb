require "spec_helper"

class DomainFilterDomain < Aver::Domain
  domain_name "domain-filter-test"
  action :setup_domain_filter_test
  assertion :filter_skips_non_matching
  assertion :filter_runs_matching
end

class DomainFilterAdapter < Aver::Adapter
  domain DomainFilterDomain
  protocol :unit, -> { {} }

  def setup_domain_filter_test(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "FilterTarget"
      action :ping
    end
    state[:d] = d
  end

  def filter_skips_non_matching(state, **kw)
    old = ENV["AVER_DOMAIN"]
    begin
      ENV["AVER_DOMAIN"] = "SomeOtherDomain"
      d = state[:d]
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

  def filter_runs_matching(state, **kw)
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

Aver.register(DomainFilterAdapter)

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

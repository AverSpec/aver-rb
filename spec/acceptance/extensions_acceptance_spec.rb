require "spec_helper"

class ExtensionsDomain < Aver::Domain
  domain_name "extensions-test"
  action :run_end_to_end_extension
  action :setup_parent_adapter_in_config
  action :setup_extension_parent_tracking
  assertion :end_to_end_trace_correct
  assertion :parent_adapter_found_via_config
  assertion :extension_tracks_parent
end

class ExtensionsAdapter < Aver::Adapter
  domain ExtensionsDomain
  protocol :unit, -> { {} }

  def run_end_to_end_extension(state, **kw)
    base = Class.new(Aver::Domain) do
      domain_name "AuthBase"
      action :login
      assertion :is_logged_in
    end
    extended = base.extend_domain("AdminAuth") do
      action :grant_admin
      assertion :is_admin
    end
    dd = extended
    a = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { { user: nil, admin: false } }
      define_method(:login) { |ctx, **k| ctx[:user] = k[:username] }
      define_method(:is_logged_in) { |ctx| raise "not logged in" unless ctx[:user] }
      define_method(:grant_admin) { |ctx, **k| ctx[:admin] = true }
      define_method(:is_admin) { |ctx| raise "not admin" unless ctx[:admin] }
    end.new
    proto = Aver::UnitProtocol.new(-> { { user: nil, admin: false } }, name: "unit")
    ctx = Aver::Context.new(domain: extended, adapter: a, protocol_ctx: proto.setup)
    ctx.given.login(username: "alice")
    ctx.then.is_logged_in
    ctx.when.grant_admin
    ctx.then.is_admin
    state[:trace] = ctx.trace
  end

  def setup_parent_adapter_in_config(state, **kw)
    base = Class.new(Aver::Domain) do
      domain_name "ConfigBase"
      action :go
      assertion :check
    end
    child = base.extend_domain("ConfigChild") do
      action :extra
    end
    dd = base
    ac = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:go) { |ctx, **k| nil }
      define_method(:check) { |ctx| nil }
    end
    config = Aver::Configuration.new
    config.register(ac)
    state[:found] = config.find_adapters(base)
    state[:parent_adapter_class] = ac
  end

  def setup_extension_parent_tracking(state, **kw)
    parent = Class.new(Aver::Domain) do
      domain_name "ExtParentTrack"
      action :base_op
    end
    child = parent.extend_domain("ExtChildTrack") do
      action :extra
    end
    state[:child] = child
    state[:parent] = parent
  end

  def end_to_end_trace_correct(state, **kw)
    trace = state[:trace]
    raise "Expected 4 trace entries, got #{trace.length}" unless trace.length == 4
    statuses = trace.map(&:status)
    unless statuses.all? { |s| s == "pass" }
      raise "Expected all pass, got #{statuses.inspect}"
    end
  end

  def parent_adapter_found_via_config(state, **kw)
    found = state[:found]
    raise "Expected 1 adapter found, got #{found.length}" unless found.length == 1
    raise "Expected parent adapter to be found" unless found[0].adapter_class.equal?(state[:parent_adapter_class])
  end

  def extension_tracks_parent(state, **kw)
    child = state[:child]
    parent = state[:parent]
    raise "Expected child.parent to be parent" unless child.parent == parent
    raise "Expected parent name 'ExtParentTrack', got '#{child.parent.name}'" unless child.parent.name == "ExtParentTrack"
  end
end

Aver.register(ExtensionsAdapter)

RSpec.describe "Extensions acceptance", aver: ExtensionsDomain do

  aver_test "extended domain works end-to-end through context" do |ctx|
    ctx.when.run_end_to_end_extension
    ctx.then.end_to_end_trace_correct
  end

  aver_test "extended domain registered via parent adapter in config" do |ctx|
    ctx.when.setup_parent_adapter_in_config
    ctx.then.parent_adapter_found_via_config
  end

  aver_test "extension tracks parent domain" do |ctx|
    ctx.when.setup_extension_parent_tracking
    ctx.then.extension_tracks_parent
  end
end

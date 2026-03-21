require "spec_helper"

ExtensionsDomain = Aver.domain("extensions-test") do
  action :run_end_to_end_extension
  action :setup_parent_adapter_in_config
  action :setup_extension_parent_tracking
  assertion :end_to_end_trace_correct
  assertion :parent_adapter_found_via_config
  assertion :extension_tracks_parent
end

ExtensionsAdapter = Aver.implement(ExtensionsDomain, protocol: Aver.unit { {} }) do
  handle(:run_end_to_end_extension) do |state, p|
    base = Aver.domain("AuthBase") do
      action :login
      assertion :is_logged_in
    end
    extended = base.extend("AdminAuth") do
      action :grant_admin
      assertion :is_admin
    end
    proto = Aver.unit { { user: nil, admin: false } }
    a = Aver.implement(extended, protocol: proto) do
      handle(:login) { |ctx, payload| ctx[:user] = payload[:username] }
      handle(:is_logged_in) { |ctx, payload| raise "not logged in" unless ctx[:user] }
      handle(:grant_admin) { |ctx, payload| ctx[:admin] = true }
      handle(:is_admin) { |ctx, payload| raise "not admin" unless ctx[:admin] }
    end
    ctx = Aver::Context.new(domain: extended, adapter: a, protocol_ctx: proto.setup)
    ctx.given.login(username: "alice")
    ctx.then.is_logged_in
    ctx.when.grant_admin
    ctx.then.is_admin
    state[:trace] = ctx.trace
  end

  handle(:setup_parent_adapter_in_config) do |state, p|
    base = Aver.domain("ConfigBase") do
      action :go
      assertion :check
    end
    child = base.extend("ConfigChild") do
      action :extra
    end
    proto = Aver.unit { {} }
    parent_adapter = Aver.implement(base, protocol: proto) do
      handle(:go) { |ctx, payload| nil }
      handle(:check) { |ctx, payload| nil }
    end
    Aver.configuration.reset!
    Aver.configuration.adapters << parent_adapter
    state[:found] = Aver.configuration.find_adapters(child)
    state[:parent_adapter] = parent_adapter
  end

  handle(:setup_extension_parent_tracking) do |state, p|
    parent = Aver.domain("ExtParentTrack") do
      action :base_op
    end
    child = parent.extend("ExtChildTrack") do
      action :extra
    end
    state[:child] = child
    state[:parent] = parent
  end

  handle(:end_to_end_trace_correct) do |state, p|
    trace = state[:trace]
    raise "Expected 4 trace entries, got #{trace.length}" unless trace.length == 4
    statuses = trace.map(&:status)
    unless statuses.all? { |s| s == "pass" }
      raise "Expected all pass, got #{statuses.inspect}"
    end
  end

  handle(:parent_adapter_found_via_config) do |state, p|
    found = state[:found]
    raise "Expected 1 adapter found, got #{found.length}" unless found.length == 1
    raise "Expected parent adapter to be found" unless found[0].equal?(state[:parent_adapter])
  end

  handle(:extension_tracks_parent) do |state, p|
    child = state[:child]
    parent = state[:parent]
    raise "Expected child.parent to be parent" unless child.parent == parent
    raise "Expected parent name 'ExtParentTrack', got '#{child.parent.name}'" unless child.parent.name == "ExtParentTrack"
  end
end

Aver.configuration.adapters << ExtensionsAdapter

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

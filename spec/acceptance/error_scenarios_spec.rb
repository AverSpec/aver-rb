require "spec_helper"

ErrorScenariosDomain = Aver.domain("error-scenarios") do
  assertion :missing_marker_raises_no_method_error
  assertion :wrong_proxy_kind_raises_type_error
  assertion :incomplete_adapter_raises_adapter_error
  assertion :extra_handlers_raise_adapter_error
end

ErrorScenariosAdapter = Aver.implement(ErrorScenariosDomain, protocol: Aver.unit { {} }) do
  handle(:missing_marker_raises_no_method_error) do |state, p|
    d = Aver.domain("err-missing") { action :real_action }
    proto = Aver.unit { {} }
    a = Aver.implement(d, protocol: proto) do
      handle(:real_action) { |ctx, payload| nil }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)
    begin
      ctx.when.nonexistent_marker
      raise "Expected NoMethodError but none raised"
    rescue NoMethodError => e
      raise "Expected error to match /no marker/, got: #{e.message}" unless e.message.match?(/no marker 'nonexistent_marker'/)
    end
  end

  handle(:wrong_proxy_kind_raises_type_error) do |state, p|
    d = Aver.domain("err-proxy") do
      action :do_thing
      assertion :verify_thing
    end
    proto = Aver.unit { {} }
    a = Aver.implement(d, protocol: proto) do
      handle(:do_thing) { |ctx, payload| nil }
      handle(:verify_thing) { |ctx, payload| nil }
    end
    ctx = Aver::Context.new(domain: d, adapter: a, protocol_ctx: proto.setup)

    begin
      ctx.when.verify_thing
      raise "Expected TypeError for ctx.when.verify_thing but none raised"
    rescue TypeError => e
      raise "Expected /assertion.*ctx.when.*only accepts/, got: #{e.message}" unless e.message.match?(/assertion.*ctx\.when.*only accepts/)
    end

    begin
      ctx.then.do_thing
      raise "Expected TypeError for ctx.then.do_thing but none raised"
    rescue TypeError => e
      raise "Expected /action.*ctx.then.*only accepts/, got: #{e.message}" unless e.message.match?(/action.*ctx\.then.*only accepts/)
    end

    begin
      ctx.query.do_thing
      raise "Expected TypeError for ctx.query.do_thing but none raised"
    rescue TypeError => e
      raise "Expected /action.*ctx.query.*only accepts/, got: #{e.message}" unless e.message.match?(/action.*ctx\.query.*only accepts/)
    end
  end

  handle(:incomplete_adapter_raises_adapter_error) do |state, p|
    d = Aver.domain("err-incomplete") do
      action :handle_this
      action :handle_that
      query :fetch_status, returns: String
      assertion :status_is_ok
    end
    proto = Aver.unit { {} }
    begin
      Aver.implement(d, protocol: proto) do
        handle(:handle_this) { |ctx, payload| nil }
        handle(:status_is_ok) { |ctx, payload| nil }
      end
      raise "Expected AdapterError but none raised"
    rescue Aver::AdapterError => e
      raise "Expected /Missing handlers/, got: #{e.message}" unless e.message.match?(/Missing handlers/)
    end
  end

  handle(:extra_handlers_raise_adapter_error) do |state, p|
    d = Aver.domain("err-extra") { action :go }
    proto = Aver.unit { {} }
    begin
      Aver.implement(d, protocol: proto) do
        handle(:go) { |ctx, payload| nil }
        handle(:bogus) { |ctx, payload| nil }
      end
      raise "Expected AdapterError but none raised"
    rescue Aver::AdapterError => e
      raise "Expected /Extra handlers.*bogus/, got: #{e.message}" unless e.message.match?(/Extra handlers.*bogus/)
    end
  end
end

Aver.configuration.adapters << ErrorScenariosAdapter

RSpec.describe "Error scenarios acceptance", aver: ErrorScenariosDomain do

  aver_test "missing marker raises NoMethodError" do |ctx|
    ctx.then.missing_marker_raises_no_method_error
  end

  aver_test "wrong proxy kind raises TypeError" do |ctx|
    ctx.then.wrong_proxy_kind_raises_type_error
  end

  aver_test "incomplete adapter raises AdapterError" do |ctx|
    ctx.then.incomplete_adapter_raises_adapter_error
  end

  aver_test "extra handlers raise AdapterError" do |ctx|
    ctx.then.extra_handlers_raise_adapter_error
  end
end

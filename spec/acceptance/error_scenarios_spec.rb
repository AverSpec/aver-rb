require "spec_helper"

class ErrorScenariosDomain < Aver::Domain
  domain_name "error-scenarios"
  assertion :missing_marker_raises_no_method_error
  assertion :wrong_proxy_kind_raises_type_error
  assertion :incomplete_adapter_raises_adapter_error
  assertion :extra_handlers_raise_adapter_error
end

class ErrorScenariosAdapter < Aver::Adapter
  domain ErrorScenariosDomain
  protocol :unit, -> { {} }

  def missing_marker_raises_no_method_error(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "err-missing"
      action :real_action
    end
    dd = d
    adapter_class = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:real_action) { |ctx, **k| nil }
    end
    proto = Aver::UnitProtocol.new(-> { {} }, name: "unit")
    ctx = Aver::Context.new(domain: d, adapter: adapter_class.new, protocol_ctx: proto.setup)
    begin
      ctx.when.nonexistent_marker
      raise "Expected NoMethodError but none raised"
    rescue NoMethodError => e
      raise "Expected error to match /no marker/, got: #{e.message}" unless e.message.match?(/no marker 'nonexistent_marker'/)
    end
  end

  def wrong_proxy_kind_raises_type_error(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "err-proxy"
      action :do_thing
      assertion :verify_thing
    end
    dd = d
    adapter_class = Class.new(Aver::Adapter) do
      domain dd
      protocol :unit, -> { {} }
      define_method(:do_thing) { |ctx, **k| nil }
      define_method(:verify_thing) { |ctx, **k| nil }
    end
    proto = Aver::UnitProtocol.new(-> { {} }, name: "unit")
    ctx = Aver::Context.new(domain: d, adapter: adapter_class.new, protocol_ctx: proto.setup)

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

  def incomplete_adapter_raises_adapter_error(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "err-incomplete"
      action :handle_this
      action :handle_that
      query :fetch_status, returns: String
      assertion :status_is_ok
    end
    dd = d
    begin
      incomplete = Class.new(Aver::Adapter) do
        domain dd
        protocol :unit, -> { {} }
        define_method(:handle_this) { |ctx, **k| nil }
        define_method(:status_is_ok) { |ctx, **k| nil }
      end
      incomplete.validate!
      raise "Expected AdapterError but none raised"
    rescue Aver::AdapterError => e
      raise "Expected /Missing handlers/, got: #{e.message}" unless e.message.match?(/Missing handlers/)
    end
  end

  def extra_handlers_raise_adapter_error(state, **kw)
    d = Class.new(Aver::Domain) do
      domain_name "err-extra"
      action :go
    end
    dd = d
    begin
      extra = Class.new(Aver::Adapter) do
        domain dd
        protocol :unit, -> { {} }
        define_method(:go) { |ctx, **k| nil }
        define_method(:bogus) { |ctx, **k| nil }
      end
      extra.validate!
      raise "Expected AdapterError but none raised"
    rescue Aver::AdapterError => e
      raise "Expected /Extra handlers.*bogus/, got: #{e.message}" unless e.message.match?(/Extra handlers.*bogus/)
    end
  end
end

Aver.register(ErrorScenariosAdapter)

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

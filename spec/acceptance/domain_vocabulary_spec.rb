require "spec_helper"

DomainVocabularyDomain = Aver.domain("domain-vocabulary") do
  action :create_vocabulary_domain
  action :create_metadata_domain
  action :create_propagation_domain
  action :create_kinds_domain
  assertion :captures_all_marker_kinds
  assertion :markers_store_metadata
  assertion :domain_name_propagates
  assertion :markers_report_correct_kind
end

DomainVocabularyAdapter = Aver.implement(DomainVocabularyDomain, protocol: Aver.unit { {} }) do
  handle(:create_vocabulary_domain) do |state, p|
    state[:domain] = Aver.domain("vocabulary") do
      action :create
      action :update
      query :get_count, returns: Integer
      query :get_item, payload: Hash, returns: Hash
      assertion :exists
      assertion :is_valid
    end
  end

  handle(:create_metadata_domain) do |state, p|
    state[:domain] = Aver.domain("meta-test") do
      action :go, payload: { id: String }
      query :peek, payload: Hash, returns: Array
      assertion :check, payload: { status: String }
    end
  end

  handle(:create_propagation_domain) do |state, p|
    state[:domain] = Aver.domain("propagation") do
      action :go
      query :peek, returns: Hash
      assertion :check
    end
  end

  handle(:create_kinds_domain) do |state, p|
    state[:domain] = Aver.domain("vocab-kinds") do
      action :do_thing
      query :get_thing, returns: Hash
      assertion :check_thing
    end
  end

  handle(:captures_all_marker_kinds) do |state, p|
    d = state[:domain]
    raise "Expected 6 markers, got #{d.markers.length}" unless d.markers.length == 6
    kinds = d.markers.values.map(&:kind)
    raise "Expected 2 actions, got #{kinds.count(:action)}" unless kinds.count(:action) == 2
    raise "Expected 2 queries, got #{kinds.count(:query)}" unless kinds.count(:query) == 2
    raise "Expected 2 assertions, got #{kinds.count(:assertion)}" unless kinds.count(:assertion) == 2
  end

  handle(:markers_store_metadata) do |state, p|
    d = state[:domain]
    unless d.markers[:go].payload_type == { id: String }
      raise "Expected go payload { id: String }, got #{d.markers[:go].payload_type.inspect}"
    end
    unless d.markers[:peek].return_type == Array
      raise "Expected peek returns Array, got #{d.markers[:peek].return_type.inspect}"
    end
    unless d.markers[:check].payload_type == { status: String }
      raise "Expected check payload { status: String }, got #{d.markers[:check].payload_type.inspect}"
    end
  end

  handle(:domain_name_propagates) do |state, p|
    d = state[:domain]
    d.markers.each_value do |m|
      unless m.domain_name == "propagation"
        raise "Expected domain_name 'propagation', got '#{m.domain_name}'"
      end
    end
  end

  handle(:markers_report_correct_kind) do |state, p|
    d = state[:domain]
    raise "Expected :action, got #{d.markers[:do_thing].kind}" unless d.markers[:do_thing].kind == :action
    raise "Expected :query, got #{d.markers[:get_thing].kind}" unless d.markers[:get_thing].kind == :query
    raise "Expected :assertion, got #{d.markers[:check_thing].kind}" unless d.markers[:check_thing].kind == :assertion
  end
end

Aver.configuration.adapters << DomainVocabularyAdapter

RSpec.describe "Domain vocabulary acceptance", aver: DomainVocabularyDomain do

  aver_test "captures all marker kinds" do |ctx|
    ctx.given.create_vocabulary_domain
    ctx.then.captures_all_marker_kinds
  end

  aver_test "markers store metadata" do |ctx|
    ctx.given.create_metadata_domain
    ctx.then.markers_store_metadata
  end

  aver_test "domain name propagates to markers" do |ctx|
    ctx.given.create_propagation_domain
    ctx.then.domain_name_propagates
  end

  aver_test "markers report correct kind" do |ctx|
    ctx.given.create_kinds_domain
    ctx.then.markers_report_correct_kind
  end
end

require "spec_helper"

RSpec.describe "Smoke tests" do
  describe "module loading" do
    it "Aver module is defined" do
      expect(defined?(Aver)).to eq("constant")
    end

    it "Aver::Domain is loadable" do
      expect(defined?(Aver::Domain)).to eq("constant")
    end

    it "Aver::Adapter is loadable" do
      expect(defined?(Aver::Adapter)).to eq("constant")
    end

    it "Aver::Protocol is loadable" do
      expect(defined?(Aver::Protocol)).to eq("constant")
    end

    it "Aver::Context is loadable" do
      expect(defined?(Aver::Context)).to eq("constant")
    end

    it "Aver::NarrativeProxy is loadable" do
      expect(defined?(Aver::NarrativeProxy)).to eq("constant")
    end

    it "Aver::TraceEntry is loadable" do
      expect(defined?(Aver::TraceEntry)).to eq("constant")
    end

    it "Aver::Configuration is loadable" do
      expect(defined?(Aver::Configuration)).to eq("constant")
    end

    it "Aver::Approvals is loadable" do
      expect(defined?(Aver::Approvals)).to eq("constant")
    end

    it "Aver::OtlpReceiver is loadable" do
      expect(defined?(Aver::OtlpReceiver)).to eq("constant")
    end
  end

  describe "top-level API" do
    it "Aver.domain returns Domain" do
      d = Aver.domain("smoke-test")
      expect(d).to be_a(Aver::Domain)
    end

    it "Aver.implement returns Adapter" do
      d = Aver.domain("smoke-impl") { action :go }
      p = Aver.unit { nil }
      a = Aver.implement(d, protocol: p) do
        handle(:go) { |ctx, payload| nil }
      end
      expect(a).to be_a(Aver::Adapter)
    end

    it "Aver.unit returns UnitProtocol" do
      p = Aver.unit { nil }
      expect(p).to be_a(Aver::UnitProtocol)
    end

    it "Aver.suite returns Suite" do
      d = Aver.domain("smoke-suite")
      s = Aver.suite(d)
      expect(s).to be_a(Aver::Suite)
    end

    it "Aver.configuration exists" do
      expect(Aver.configuration).to be_a(Aver::Configuration)
    end

    it "Marker instances have correct kinds" do
      d = Aver.domain("marker-check") do
        action :a
        query :q, returns: Integer
        assertion :c
      end
      expect(d.markers[:a].kind).to eq(:action)
      expect(d.markers[:q].kind).to eq(:query)
      expect(d.markers[:c].kind).to eq(:assertion)
    end

    it "Aver.with_fixture returns FixtureProtocol" do
      p = Aver.unit { nil }
      wrapped = Aver.with_fixture(p, before: -> {})
      expect(wrapped).to be_a(Aver::FixtureProtocol)
    end

    it "CLI module is loadable" do
      require "averspec/cli"
      expect(defined?(Aver::CLI)).to eq("constant")
    end

    it "Aver.format_trace is callable" do
      expect(Aver).to respond_to(:format_trace)
    end

    it "Aver.eventually is callable" do
      expect(Aver).to respond_to(:eventually)
    end
  end
end

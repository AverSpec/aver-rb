require "spec_helper"

RSpec.describe Aver::Domain do
  describe "creation" do
    it "stores the domain name" do
      domain = Class.new(Aver::Domain) { domain_name "task-board" }
      expect(domain.name).to eq("task-board")
    end

    it "creates an empty markers hash by default" do
      domain = Class.new(Aver::Domain) { domain_name "empty" }
      expect(domain.markers).to eq({})
    end
  end

  describe "DSL" do
    let(:domain) do
      Class.new(Aver::Domain) do
        domain_name "task-board"
        action :create_task, payload: { title: String }
        action :move_task, payload: { title: String, status: String }
        query :task_details, payload: String, returns: Hash
        assertion :task_in_status, payload: { title: String, status: String }
      end
    end

    it "registers actions" do
      expect(domain.markers[:create_task].kind).to eq(:action)
      expect(domain.markers[:move_task].kind).to eq(:action)
    end

    it "registers queries" do
      expect(domain.markers[:task_details].kind).to eq(:query)
    end

    it "registers assertions" do
      expect(domain.markers[:task_in_status].kind).to eq(:assertion)
    end

    it "stores payload types" do
      expect(domain.markers[:create_task].payload_type).to eq({ title: String })
    end

    it "stores return types on queries" do
      expect(domain.markers[:task_details].return_type).to eq(Hash)
    end

    it "enumerates all markers" do
      expect(domain.markers.keys).to contain_exactly(:create_task, :move_task, :task_details, :task_in_status)
    end

    it "sets domain_name on each marker" do
      domain.markers.each_value do |marker|
        expect(marker.domain_name).to eq("task-board")
      end
    end
  end

  describe "extension" do
    let(:parent) do
      Class.new(Aver::Domain) do
        domain_name "base"
        action :login
      end
    end

    it "inherits parent markers" do
      child = parent.extend_domain("child") do
        action :logout
      end
      expect(child.markers.keys).to contain_exactly(:login, :logout)
    end

    it "tracks parent reference" do
      child = parent.extend_domain("child")
      expect(child.parent).to eq(parent)
    end

    it "does not modify the parent" do
      parent.extend_domain("child") do
        action :logout
      end
      expect(parent.markers.keys).to eq([:login])
    end
  end
end

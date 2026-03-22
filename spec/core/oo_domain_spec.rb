require "spec_helper"

# Test domain using OO class-based API
class SpecTaskBoard < Aver::Domain
  domain_name "task-board"

  action :create_task, payload: { title: String, status: String }
  action :move_task, payload: { title: String, status: String }
  query :task_details, payload: String, returns: Hash
  assertion :task_in_status, payload: { title: String, status: String }
end

class SpecEmptyDomain < Aver::Domain
  domain_name "empty-domain"
end

class SpecAutoNamed < Aver::Domain
  # No explicit domain_name; should auto-derive
  action :ping
end

RSpec.describe "OO Domain (class-based)" do
  describe "class macro registration" do
    it "registers actions" do
      expect(SpecTaskBoard.markers[:create_task].kind).to eq(:action)
      expect(SpecTaskBoard.markers[:move_task].kind).to eq(:action)
    end

    it "registers queries" do
      expect(SpecTaskBoard.markers[:task_details].kind).to eq(:query)
    end

    it "registers assertions" do
      expect(SpecTaskBoard.markers[:task_in_status].kind).to eq(:assertion)
    end

    it "stores payload types" do
      expect(SpecTaskBoard.markers[:create_task].payload_type).to eq({ title: String, status: String })
    end

    it "stores return types on queries" do
      expect(SpecTaskBoard.markers[:task_details].return_type).to eq(Hash)
    end

    it "enumerates all markers" do
      expect(SpecTaskBoard.markers.keys).to contain_exactly(:create_task, :move_task, :task_details, :task_in_status)
    end

    it "sets domain_name on each marker" do
      SpecTaskBoard.markers.each_value do |marker|
        expect(marker.domain_name).to eq("task-board")
      end
    end
  end

  describe "domain_name" do
    it "stores explicit domain name" do
      expect(SpecTaskBoard.domain_name).to eq("task-board")
      expect(SpecTaskBoard.name).to eq("task-board")
    end

    it "auto-derives domain name from class name" do
      expect(SpecAutoNamed.domain_name).to eq("spec-auto-named")
    end

    it "empty domain has no markers" do
      expect(SpecEmptyDomain.markers).to eq({})
    end
  end

  describe "extend_domain" do
    it "creates a child domain with inherited markers" do
      child = SpecTaskBoard.extend_domain("admin-task-board") do
        action :archive_task
      end
      expect(child.markers.keys).to contain_exactly(:create_task, :move_task, :task_details, :task_in_status, :archive_task)
    end

    it "tracks parent" do
      child = SpecTaskBoard.extend_domain("child-board")
      expect(child.parent).to eq(SpecTaskBoard)
    end

    it "does not modify parent" do
      SpecTaskBoard.extend_domain("isolated") do
        action :delete_task
      end
      expect(SpecTaskBoard.markers.keys).to contain_exactly(:create_task, :move_task, :task_details, :task_in_status)
    end

    it "detects collision in extension" do
      expect {
        SpecTaskBoard.extend_domain("bad-child") do
          query :create_task, returns: Hash
        end
      }.to raise_error(Aver::DomainCollisionError, /create_task/)
    end
  end

  describe "Domain is a proper class" do
    it "is a Class" do
      expect(Aver::Domain).to be_a(Class)
    end

    it "subclasses can be created" do
      klass = Class.new(Aver::Domain) do
        domain_name "dynamic"
        action :go
      end
      expect(klass.markers[:go].kind).to eq(:action)
      expect(klass.domain_name).to eq("dynamic")
    end
  end
end

require "spec_helper"

RSpec.describe Aver::Marker do
  describe "action marker" do
    it "has kind :action" do
      marker = Aver::Marker.new(kind: :action)
      expect(marker.kind).to eq(:action)
    end

    it "stores payload type" do
      marker = Aver::Marker.new(kind: :action, payload_type: { title: String })
      expect(marker.payload_type).to eq({ title: String })
    end
  end

  describe "query marker" do
    it "has kind :query" do
      marker = Aver::Marker.new(kind: :query)
      expect(marker.kind).to eq(:query)
    end

    it "stores return type" do
      marker = Aver::Marker.new(kind: :query, return_type: Hash)
      expect(marker.return_type).to eq(Hash)
    end
  end

  describe "assertion marker" do
    it "has kind :assertion" do
      marker = Aver::Marker.new(kind: :assertion)
      expect(marker.kind).to eq(:assertion)
    end
  end

  describe "naming" do
    it "stores name and domain_name" do
      marker = Aver::Marker.new(kind: :action)
      marker.name = :create_task
      marker.domain_name = "task-board"
      expect(marker.name).to eq(:create_task)
      expect(marker.domain_name).to eq("task-board")
    end
  end
end

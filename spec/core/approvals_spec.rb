require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "Aver.approve" do
  let(:tmpdir) { Dir.mktmpdir("aver_approvals") }
  after { FileUtils.rm_rf(tmpdir) }

  def approve_in_tmpdir(value, name: "test", scrub: nil, approve_mode: false)
    old_env = ENV["AVER_APPROVE"]
    ENV["AVER_APPROVE"] = "1" if approve_mode
    begin
      Aver::Approvals.approve(
        value,
        name: name,
        test_name: "test_example",
        file_path: File.join(tmpdir, "fake_spec.rb"),
        scrub: scrub
      )
    ensure
      ENV["AVER_APPROVE"] = old_env
    end
  end

  it "raises when no baseline exists and not in approve mode" do
    expect {
      old = ENV["AVER_APPROVE"]
      ENV.delete("AVER_APPROVE")
      begin
        Aver::Approvals.approve(
          "hello",
          name: "missing",
          test_name: "test_example",
          file_path: File.join(tmpdir, "fake_spec.rb")
        )
      ensure
        ENV["AVER_APPROVE"] = old
      end
    }.to raise_error(Aver::ApprovalError, /No approved baseline/)
  end

  it "creates baseline in approve mode" do
    approve_in_tmpdir("hello world", approve_mode: true)
    approved_path = File.join(tmpdir, "__approvals__", "test_example", "test.approved.txt")
    expect(File.exist?(approved_path)).to be true
    expect(File.read(approved_path)).to eq("hello world")
  end

  it "passes when value matches baseline" do
    approve_in_tmpdir("stable", approve_mode: true)
    # Second call should pass without approve mode
    old_env = ENV["AVER_APPROVE"]
    ENV.delete("AVER_APPROVE")
    begin
      expect {
        Aver::Approvals.approve(
          "stable",
          name: "test",
          test_name: "test_example",
          file_path: File.join(tmpdir, "fake_spec.rb")
        )
      }.not_to raise_error
    ensure
      ENV["AVER_APPROVE"] = old_env
    end
  end

  it "raises on mismatch with diff files" do
    approve_in_tmpdir("original", approve_mode: true)

    old_env = ENV["AVER_APPROVE"]
    ENV.delete("AVER_APPROVE")
    begin
      expect {
        Aver::Approvals.approve(
          "changed",
          name: "test",
          test_name: "test_example",
          file_path: File.join(tmpdir, "fake_spec.rb")
        )
      }.to raise_error(Aver::ApprovalError, /Approval mismatch/)

      received_path = File.join(tmpdir, "__approvals__", "test_example", "test.received.txt")
      diff_path = File.join(tmpdir, "__approvals__", "test_example", "test.diff.txt")
      expect(File.exist?(received_path)).to be true
      expect(File.exist?(diff_path)).to be true
    ensure
      ENV["AVER_APPROVE"] = old_env
    end
  end

  it "updates baseline on mismatch when in approve mode" do
    approve_in_tmpdir("v1", approve_mode: true)
    approve_in_tmpdir("v2", approve_mode: true)

    approved_path = File.join(tmpdir, "__approvals__", "test_example", "test.approved.txt")
    expect(File.read(approved_path)).to eq("v2")
  end

  it "serializes hashes as JSON" do
    approve_in_tmpdir({ name: "Alice", age: 30 }, approve_mode: true)
    approved_path = File.join(tmpdir, "__approvals__", "test_example", "test.approved.json")
    expect(File.exist?(approved_path)).to be true
    content = File.read(approved_path)
    expect(content).to include("Alice")
  end

  it "serializes arrays as JSON" do
    approve_in_tmpdir([1, 2, 3], approve_mode: true)
    approved_path = File.join(tmpdir, "__approvals__", "test_example", "test.approved.json")
    expect(File.exist?(approved_path)).to be true
  end

  it "applies scrubbers" do
    value = "id: abc-123-def, timestamp: 2026-03-21T12:00:00Z"
    approve_in_tmpdir(value, scrub: [
      { pattern: /[a-f0-9]{3}-[a-f0-9]{3}-[a-f0-9]{3}/, replacement: "<ID>" },
      { pattern: /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, replacement: "<TIMESTAMP>" },
    ], approve_mode: true)

    approved_path = File.join(tmpdir, "__approvals__", "test_example", "test.approved.txt")
    content = File.read(approved_path)
    expect(content).to eq("id: <ID>, timestamp: <TIMESTAMP>")
  end

  it "scrubbers accept string patterns" do
    value = "order-42 total"
    approve_in_tmpdir(value, scrub: [
      { pattern: "order-\\d+", replacement: "order-<N>" },
    ], approve_mode: true)

    approved_path = File.join(tmpdir, "__approvals__", "test_example", "test.approved.txt")
    content = File.read(approved_path)
    expect(content).to eq("order-<N> total")
  end

  it "characterize is an alias for approve" do
    old_env = ENV["AVER_APPROVE"]
    ENV["AVER_APPROVE"] = "1"
    begin
      expect {
        Aver::Approvals.characterize(
          "aliased",
          name: "alias_test",
          test_name: "test_alias",
          file_path: File.join(tmpdir, "fake_spec.rb")
        )
      }.not_to raise_error
    ensure
      ENV["AVER_APPROVE"] = old_env
    end
  end
end

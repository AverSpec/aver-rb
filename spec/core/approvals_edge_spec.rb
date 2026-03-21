require "spec_helper"
require "tmpdir"
require "json"
require "fileutils"

RSpec.describe "Approvals edge cases" do
  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @tmp_dir = dir
      example.run
    end
  end

  it "diff file written on mismatch" do
    name = "snapshot"
    test_name = "test_diff_check"
    approvals_dir = File.join(@tmp_dir, "__approvals__", test_name)
    FileUtils.mkdir_p(approvals_dir)

    # Write the approved baseline
    File.write(
      File.join(approvals_dir, "#{name}.approved.json"),
      JSON.pretty_generate({ "count" => 1 })
    )

    # Change value and verify mismatch
    expect {
      Aver::Approvals.approve(
        { "count" => 99 },
        name: name,
        test_name: test_name,
        file_path: File.join(@tmp_dir, "fake_test.rb")
      )
    }.to raise_error(Aver::ApprovalError, /mismatch/)

    diff_file = File.join(approvals_dir, "#{name}.diff.txt")
    received_file = File.join(approvals_dir, "#{name}.received.json")

    expect(File.exist?(diff_file)).to be true
    expect(File.exist?(received_file)).to be true

    diff_content = File.read(diff_file)
    expect(diff_content).to include("approved")
    expect(diff_content).to include("received")
  end

  it "received/diff cleaned on pass" do
    name = "snapshot"
    test_name = "test_cleanup_check"
    approvals_dir = File.join(@tmp_dir, "__approvals__", test_name)
    FileUtils.mkdir_p(approvals_dir)

    approved_text = JSON.pretty_generate({ "status" => "ok" })
    File.write(File.join(approvals_dir, "#{name}.approved.json"), approved_text)

    # Create a mismatch first
    expect {
      Aver::Approvals.approve(
        { "status" => "changed" },
        name: name,
        test_name: test_name,
        file_path: File.join(@tmp_dir, "fake_test.rb")
      )
    }.to raise_error(Aver::ApprovalError)

    diff_file = File.join(approvals_dir, "#{name}.diff.txt")
    received_file = File.join(approvals_dir, "#{name}.received.json")
    expect(File.exist?(diff_file)).to be true
    expect(File.exist?(received_file)).to be true

    # Now pass with matching content
    Aver::Approvals.approve(
      { "status" => "ok" },
      name: name,
      test_name: test_name,
      file_path: File.join(@tmp_dir, "fake_test.rb")
    )

    expect(File.exist?(diff_file)).to be false
    expect(File.exist?(received_file)).to be false
  end

  it "serializer auto-detects Hash as JSON" do
    ENV["AVER_APPROVE"] = "1"
    begin
      test_name = "test_auto_json"
      Aver::Approvals.approve(
        { key: "value" },
        name: "auto",
        test_name: test_name,
        file_path: File.join(@tmp_dir, "fake_test.rb")
      )

      approvals_dir = File.join(@tmp_dir, "__approvals__", test_name)
      expect(File.exist?(File.join(approvals_dir, "auto.approved.json"))).to be true
    ensure
      ENV.delete("AVER_APPROVE")
    end
  end

  it "serializer auto-detects String as text" do
    ENV["AVER_APPROVE"] = "1"
    begin
      test_name = "test_auto_text"
      Aver::Approvals.approve(
        "plain string",
        name: "auto",
        test_name: test_name,
        file_path: File.join(@tmp_dir, "fake_test.rb")
      )

      approvals_dir = File.join(@tmp_dir, "__approvals__", test_name)
      expect(File.exist?(File.join(approvals_dir, "auto.approved.txt"))).to be true
    ensure
      ENV.delete("AVER_APPROVE")
    end
  end
end

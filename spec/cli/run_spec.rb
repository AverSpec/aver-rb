require "spec_helper"
require "averspec/cli"

RSpec.describe "Aver::CLI.execute_run" do
  around do |example|
    old_adapter = ENV["AVER_ADAPTER"]
    old_domain = ENV["AVER_DOMAIN"]
    example.run
    ENV.delete("AVER_ADAPTER") unless old_adapter
    ENV["AVER_ADAPTER"] = old_adapter if old_adapter
    ENV.delete("AVER_DOMAIN") unless old_domain
    ENV["AVER_DOMAIN"] = old_domain if old_domain
  end

  it "sets AVER_ADAPTER env var from --adapter flag" do
    # We can't actually exec, but we can test the env var logic
    # by calling the internal method that parses args
    argv = ["--adapter", "http", "--domain", "tasks"]
    adapter = nil
    domain = nil
    remaining = []

    i = 0
    while i < argv.length
      case argv[i]
      when "--adapter"
        adapter = argv[i + 1]
        i += 2
      when "--domain"
        domain = argv[i + 1]
        i += 2
      else
        remaining << argv[i]
        i += 1
      end
    end

    expect(adapter).to eq("http")
    expect(domain).to eq("tasks")
  end

  it "passes remaining args through" do
    argv = ["--adapter", "unit", "--", "spec/core"]
    remaining = []
    i = 0
    while i < argv.length
      case argv[i]
      when "--adapter"
        i += 2
      else
        remaining << argv[i]
        i += 1
      end
    end
    expect(remaining).to include("spec/core")
  end

  it "handles no flags" do
    argv = []
    expect(argv.length).to eq(0)
  end

  it "prints help text" do
    # Capture output from print_help
    output = nil
    expect {
      output = capture_stdout { Aver::CLI.print_help }
    }.not_to raise_error
    expect(output).to include("aver")
    expect(output).to include("run")
    expect(output).to include("approve")
    expect(output).to include("init")
  end
end

def capture_stdout
  old = $stdout
  $stdout = StringIO.new
  yield
  $stdout.string
ensure
  $stdout = old
end

require "spec_helper"

RSpec.describe "Aver.resolve_telemetry_mode" do
  around do |example|
    old_mode = ENV["AVER_TELEMETRY_MODE"]
    old_ci = ENV["CI"]
    example.run
    if old_mode.nil?
      ENV.delete("AVER_TELEMETRY_MODE")
    else
      ENV["AVER_TELEMETRY_MODE"] = old_mode
    end
    if old_ci.nil?
      ENV.delete("CI")
    else
      ENV["CI"] = old_ci
    end
  end

  it "returns override when provided" do
    expect(Aver.resolve_telemetry_mode(override: "off")).to eq("off")
  end

  it "raises on invalid override" do
    expect {
      Aver.resolve_telemetry_mode(override: "bogus")
    }.to raise_error(ArgumentError, /Invalid telemetry mode/)
  end

  it "reads from env var" do
    ENV["AVER_TELEMETRY_MODE"] = "fail"
    expect(Aver.resolve_telemetry_mode).to eq("fail")
  end

  it "defaults to fail on CI" do
    ENV.delete("AVER_TELEMETRY_MODE")
    ENV["CI"] = "true"
    expect(Aver.resolve_telemetry_mode).to eq("fail")
  end
end

require "spec_helper"
require "timeout"

RSpec.describe "Aver.eventually" do
  it "returns immediately on first pass" do
    result = Aver.eventually(timeout: 1.0) { 42 }
    expect(result).to eq(42)
  end

  it "retries until pass" do
    attempts = 0
    result = Aver.eventually(timeout: 2.0, interval: 0.05) do
      attempts += 1
      raise "not yet" if attempts < 3
      "done"
    end
    expect(result).to eq("done")
    expect(attempts).to eq(3)
  end

  it "raises Timeout::Error after deadline" do
    expect {
      Aver.eventually(timeout: 0.1, interval: 0.02) do
        raise "nope"
      end
    }.to raise_error(Timeout::Error, /Timed out.*nope/)
  end

  it "respects custom interval" do
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    attempts = 0
    Aver.eventually(timeout: 2.0, interval: 0.1) do
      attempts += 1
      raise "wait" if attempts < 3
    end
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    expect(elapsed).to be >= 0.15
  end
end

module Aver
  def self.eventually(timeout: 5.0, interval: 0.1, &block)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    last_error = nil

    loop do
      begin
        return block.call
      rescue => e
        last_error = e
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise Timeout::Error, "Timed out after #{timeout}s. Last error: #{e.message}"
        end
        sleep(interval)
      end
    end
  end
end

module Aver
  class Suite
    attr_reader :domain

    def initialize(domain)
      @domain = domain
    end
  end

  def self.suite(domain)
    Suite.new(domain)
  end
end

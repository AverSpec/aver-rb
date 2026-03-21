require "averspec"
require "averspec/rspec"

RSpec.configure do |config|
  config.before(:suite) { Aver.configuration.reset! }
end

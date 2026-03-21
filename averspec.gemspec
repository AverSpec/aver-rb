Gem::Specification.new do |s|
  s.name        = "averspec"
  s.version     = "0.0.1"
  s.summary     = "Domain-driven acceptance testing for Ruby"
  s.description = "Know your system works. Aver is a domain-driven acceptance testing framework that separates test intent from implementation."
  s.authors     = ["AverSpec"]
  s.license     = "MIT"
  s.homepage    = "https://averspec.dev"
  s.files       = Dir["lib/**/*.rb"]

  s.required_ruby_version = ">= 3.2"

  s.add_development_dependency "rspec", "~> 3.0"
end

Gem::Specification.new do |s|
  s.name        = "averspec"
  s.version     = "0.1.0"
  s.summary     = "Domain-driven acceptance testing for Ruby"
  s.description = "Know your system works. Aver is a domain-driven acceptance testing framework that separates test intent from implementation."
  s.authors     = ["Nate Jackson"]
  s.license     = "MIT"
  s.homepage    = "https://averspec.dev"
  s.metadata    = {
    "source_code_uri" => "https://github.com/AverSpec/aver-rb",
    "homepage_uri"    => "https://averspec.dev",
  }
  s.files       = Dir["lib/**/*.rb", "exe/*"]
  s.executables = ["aver"]
  s.bindir      = "exe"

  s.required_ruby_version = ">= 3.2"

  s.add_development_dependency "rspec", "~> 3.0"
  s.add_development_dependency "webrick", "~> 1.8"
end

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "next_rails/version"

Gem::Specification.new do |spec|
  spec.name          = "next_rails"
  spec.version       = NextRails::VERSION
  spec.authors       = ["Ernesto Tagwerker", "Luis Sagastume"]
  spec.email         = ["ernesto@ombulabs.com", "luis@ombulabs.com"]

  spec.summary       = %q{A toolkit to upgrade your next Rails application}
  spec.description   = %q{A set of handy tools to upgrade your Rails application and keep it up to date}
  spec.homepage     = "https://github.com/fastruby/next_rails"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rainbow", ">= 3"
  spec.add_development_dependency "bundler", ">= 1.16", "< 3.0"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.17.1"
  spec.add_development_dependency "timecop", "~> 0.9.1"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "rexml", "3.4.1" # limited on purpose, new versions don't work with old rubies
  spec.add_development_dependency "webmock", "3.20.0"
end

# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "graphql/guard/version"

Gem::Specification.new do |spec|
  spec.name          = "graphql-guard"
  spec.version       = GraphQL::Guard::VERSION
  spec.authors       = ["exAspArk"]
  spec.email         = ["exaspark@gmail.com"]

  spec.summary       = %q{Simple authorization gem for graphql-ruby}
  spec.description   = %q{Simple authorization gem for graphql-ruby}
  spec.homepage      = "https://github.com/exAspArk/graphql-guard"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(spec|images)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.1.0' # keyword args

  spec.add_runtime_dependency "graphql", ">= 1.10.0", "< 2"

  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end

# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "varnish-statsd/version"

Gem::Specification.new do |s|
  s.name        = "varnish-statsd"
  s.version     = Varnish::Statsd::VERSION
  s.authors     = ["Martin Sarsale"]
  s.email       = ["martin@sumavisos.com"]
  s.homepage    = ""
  s.summary     = %q{Varnishlog + statsd}
  s.description = %q{just a bin file}

  s.rubyforge_project = "varnish-statsd"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "varnish-rb"
  s.add_runtime_dependency "eventmachine"
  s.add_runtime_dependency "statsd-ruby"
end

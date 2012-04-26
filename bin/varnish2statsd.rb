#!/usr/bin/env ruby
require "varnish_statsd"

if not ARGV[0]
  STDERR.write("use #{$0} STATSD_HOST:STATSD_PORT \n")
  exit
end
if ARGV[0]
  if ARGV[0] == 'config'
    c = YAML.load_file(File.expand_path("~/.statsd.yml"))
    host = c[:server][:host]
    port = c[:server][:port]
  else
    host,port = ARGV[0].split(":",2)
  end
end
VarnishStatsd::VarnishStatsd.new(host,port).run

require 'varnish'
require "statsd"
require "pp"

class Log
  def initialize(host,port)
    @vd = Varnish::VSM.VSM_New
    Varnish::VSL.VSL_Setup(@vd)
    Varnish::VSL.VSL_Open(@vd, 1)
    @count = 0
    @reqs  = Hash.new{|h,k| h[k] = Hash.new{|h2,k2| h2[k2] = [] } }
    @ready = Hash.new{|h,k| h[k] = Hash.new{|h2,k2| h2[k2] = [] } }
    debug("Statsd:",host,port)
    @statsd = Statsd.new(host,port.to_i)
  end

  def run
    Varnish::VSL.VSL_Dispatch(@vd, self.method(:callback).to_proc, FFI::MemoryPointer.new(:pointer))
  end

private
  def debug(*s)
    STDERR.write(s.join(' ') + "\n") if ENV['DEBUG']
  end
  def callback(priv, tag, id, len, client_or_backend, data_pointer, bitmap)
    @count += 1
    data = data_pointer.get_string(0,len)
    @reqs[id][tag] << data
    if tag == :reqend
      @ready[id] = @reqs[id]
      @reqs.delete(id)
    end
    log(@ready)
    @ready.clear
    return 0
  end
  def log(reqs)
    reqs.each{|req_id, data|
      headers = parse_headers(data[:txheader])
      txstatus = data[:txstatus].first.to_i
      if txstatus > 0
        @statsd.increment("varnish.TxStatus.#{txstatus}",1)
        debug("TxStatus: ",txstatus)
      end
      if headers["X-Cache"]
        cache = data[:txheader]["X-Cache"].first
        @statsd.increment("varnish.cache.#{cache}",1)
        debug("X-Cache: ",cache)
      end
    }
  end
  def parse_headers(headers)
    Hash[*headers.map{|h| h.split(": ",2)}.flatten]
  end
end

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
Log.new(host,port).run

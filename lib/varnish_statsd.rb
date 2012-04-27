require "varnish_statsd/version"
require 'varnish'
require "statsd"

module VarnishStatsd
  class VarnishLog
    def initialize()
      @vd = Varnish::VSM.VSM_New
      Varnish::VSL.VSL_Setup(@vd)
      Varnish::VSL.VSL_Open(@vd, 1)
      @count = 0
      @reqs  = Hash.new{|h,k| h[k] = Hash.new{|h2,k2| h2[k2] = [] } }
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
      if tag == :reqend || id == 0
        req = @reqs[id]
        req['headers'] = parse_headers(req[:txheader])
        req_end(req)
        @reqs.delete(id)
      end
      return 0
    end
    def req_end(req)
      raise "#req_end: Override me!" 
    end
    def parse_headers(headers)
      begin
        Hash[*headers.map{|h| h.split(": ",2)}.flatten]
      rescue
        debug("Error parsing headers: #{headers.inspect}")
        {}
      end
    end
  end

  class VarnishStatsd < VarnishLog
      def initialize(host,port)
        debug("Statsd:",host,port)
        @statsd = Statsd.new(host,port.to_i)
        super()
      end
      def req_end(req)
        txstatus = req[:txstatus].first.to_i
        if txstatus > 0
          @statsd.increment("varnish.TxStatus.#{txstatus}",0.5)
          debug("TxStatus: ",txstatus)
        end
        cache = req['headers']["X-Cache"]
        if cache
          @statsd.increment("varnish.cache.#{cache}",0.5)
          debug("X-Cache: ",cache)
        end
        if req[:expkill]
          if req[:expkill] =~ /LRU/
            @statsd.increment("varnish.ExpKill.LRU",0.5)
            debug("LRU ")
          end
        end
        bot = req['headers']['From'] =~ /bingbot|googlebot/
        if bot
          @statsd.increment("varnish.bots.#{req['headers']['From'].gsub('.','')}",0.5)
          debug("Bot")
          if txstatus > 0
            @statsd.increment("varnish.bots.TxStatus.#{txstatus}",0.5)
            debug("Bot TxStatus: ",txstatus)
            @statsd.increment("varnish.bots.cache.#{cache}",0.5)
            debug("Bot Req Cache: ",txstatus)
          end

        end

      end
  end
end

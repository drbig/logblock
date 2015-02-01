# coding: utf-8
#

require 'logger'

module Logblock
  class Error < Exception; end

  class Filter
    def initialize(threshold, within, blk)
      raise Error, 'Non-positive threshold' if threshold < 1
      raise Error, 'Non-positive within' if within < 1

      @threshold = threshold
      @within = within
      @blk = blk

      @counters = Hash.new {|h,k| h[k] = Array.new }
      @timers = Array.new
    end

    def inc(key)
      cnt = @counters[key]
      cnt.push(Time.now.utc)
      return false if cnt.length < @threshold

      if cnt.last - cnt.first <= @within
        cnt.clear
        return true
      end

      cnt.shift
      false
    end

    def run!(key, match)
      instance_exec(key, match, &@blk)
    end

    def after(delay, &blk)
      raise ArgumentError, 'No block given' if blk.nil?

      thd = Thread.new do
        sleep(delay)
        blk.call
        @timers.delete(self)
      end

      @timers.push(thd)
    end
  end

  class Source
    attr_reader :path, :filters

    def initialize(path)
      @path = path

      @filters = Hash.new
    end

    def match(regexp, threshold, within, &blk)
      raise ArgumentError, 'No block given' if blk.nil?
      raise Error, 'Regexp already defined' if @filters.has_key? regexp

      @filters[regexp] = Filter.new(threshold, within, blk)
    end
  end

  class Daemon
    def initialize(opts = {}, &blk)
      raise ArgumentError, 'No block given' if blk.nil?

      @logger = opts[:logger] || Logger.new(opts[:logfile] || STDOUT)
      @daemon = opts[:daemon]

      @sources = Hash.new
      instance_eval &blk
    end

    def watch(path, &blk)
      raise Error, 'Path already defined' if @sources.has_key? path
      raise ArgumentError, 'No block given' if blk.nil?

      src = Source.new(path)
      @sources[path] = src
      src.instance_eval &blk
      src
    end

    def run!
      raise Error, 'No sources defined' if @sources.empty?

      log :debug, 'Opening source files...'
      src = Hash.new
      begin
        @sources.each_key do |path|
          log :debug, "Opening file '#{path}'"
          fd = File.open(path, 'r')
          fd.seek(0, IO::SEEK_END)
          src[fd] = @sources[path]
        end
      rescue SystemCallError => e
        src.each_key {|fd| fd.close }
        raise Error, "Couldn't open file: #{e}"
      end
      log :info, "Opened #{src.length} sources"

      log :info, "Entering main loop"
      begin
        while true
          src.keys.each do |fd|
            begin
              line = fd.readline
              s = src[fd]
              log :debug, "New line in '#{s.path}'"
              s.filters.each_pair do |regexp, filter|
                if m = line.match(regexp)
                  key = m[:key]
                  log :debug, "Match for '#{regexp}' with key '#{key}' in '#{s.path}'"
                  if filter.inc(key)
                    log :info, "Trigger for '#{regexp}' with key '#{key}' in '#{s.path}'"
                    filter.run!(key, m)
                  end
                end
              end
            rescue EOFError
              # it's ok
            end
          end
          sleep(1)
        end
      rescue SignalException => e
        log :info, 'Received an interrupt, exiting...'
      end

      log :warn, 'Outstanding threads, may leave garbage' if Thread.list.length > 1
      src.each_key {|fd| fd.close }
    end

    def log(level, msg)
      @logger.send(level, msg)
    end
  end
end

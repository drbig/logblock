# coding: utf-8
#

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'logger'
require 'pp'
require 'logblock'

logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG
#logger.formatter = lambda {|s, d, p, m| "#{d.strftime('%Y-%m-%d %H:%M:%S.%3N')} | #{s.ljust(5)} | #{m}\n" }
logger.formatter = lambda {|s, d, p, m| "#{s.ljust(5)} | #{m}\n" }

Logblock::Daemon.new(:logger => logger) do
  watch '/tmp/test1.txt' do
    match /(?<key>\d+) This is an error/, 5, 60 do |k, m|
      puts "Key - #{k} - Error triggered"
      pp m
    end
  end
  watch '/tmp/test2.txt' do
    match /(?<key>\d+) This is (.*)/, 3, 150 do |k, m|
      puts "Key - #{k} - Got something"
      pp m
      after(5) { puts "5s delayed from #{k} - #{m}" }
    end
  end
end.run!

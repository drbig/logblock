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

Logblock::Daemon.new(:logger => logger) do |d|
  d.watch '/tmp/test1.txt' do |s|
    s.match /This is an error/, 5, 60 do |m|
      puts 'Error triggered'
      pp m
    end
  end
  d.watch '/tmp/test2.txt' do |s|
    s.match /This is (.*)/, 3, 150 do |m|
      puts 'Got something'
      pp m
    end
  end
end.run!

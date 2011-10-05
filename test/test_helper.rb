require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','xedni'))
require "redis"
require 'ruby-debug'

port = 6379 #10000
$redis = Redis.new(:port => port)
begin
  $redis.get('foo')
  $redis.flushall
rescue Errno::ECONNREFUSED
  puts "Redis is not listening in port #{port}. Run:"
  puts "  bundle exec redis-server -p #{port}"
  exit
end
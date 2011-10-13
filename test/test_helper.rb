require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','xedni'))
require "redis"
require 'ruby-debug'

def load_records(values)
  values.each_pair do |id, values|
    Xedni::Record.new(id, values).save
  end
end

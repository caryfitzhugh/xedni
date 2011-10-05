require 'active_support/all'
require File.expand_path(File.join(File.dirname(__FILE__),'xedni','record'))
require File.expand_path(File.join(File.dirname(__FILE__),'xedni','filter'))
module Xedni
  def self.key_name(*args)
    args.unshift("xedni").join(':')
  end
end

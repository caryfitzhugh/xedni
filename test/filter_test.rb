require 'minitest/autorun'
require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','xedni'))

class TestFilter < MiniTest::Unit::TestCase
  def setup
    $redis.flushall
  end

  def test_saving_and_retrieving
    filter = Xedni::Filter.new('source')
    assert_equal [], filter.keys

    filter.add('publisher', 'a')
    filter.add('publisher', 'b')
    filter.add('publisher', 'c')
    filter.add('user', '1')
    filter.add('user', '2')
    filter.add('user', '3')

    assert_equal ['publisher', 'user'], filter.keys.sort

    filter.remove('user', '1')
    assert_equal ['publisher', 'user'], filter.keys.sort
    filter.remove('user', '2')
    assert_equal ['publisher', 'user'], filter.keys.sort
    filter.remove('user', '3')
    assert_equal ['publisher'], filter.keys.sort

  end
end

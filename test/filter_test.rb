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
  def test_set_math
    filter = Xedni::Filter.new('source')
    assert_equal [], filter.keys

    filter.add('cary', '1')
    filter.add('cary', '2')
    filter.add('kayo', '1')
    filter.add('kayo', '3')
    filter.add('easton', '2')
    filter.add('easton', '3')

    assert_equal ['cary', 'easton', 'kayo'], filter.keys.sort

    assert_equal ['1'], filter.anded('cary','kayo').sort
    assert_equal [], filter.anded('cary','kayo', 'easton').sort
    assert_equal ['1','2','3'], filter.ored('cary','kayo').sort
  end
end

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
    r1 = Xedni::Record.new('1').save
    r2 = Xedni::Record.new('3').save
    r3 = Xedni::Record.new('2').save

    filter = Xedni::Filter.new('source')
    assert_equal [], filter.keys

    filter.add('cary', r1)
    filter.add('cary', r2)
    filter.add('kayo', r1)
    filter.add('kayo', r3)
    filter.add('easton', r2)
    filter.add('easton', r3)

    assert_equal ['cary', 'easton', 'kayo'], filter.keys.sort

    assert_equal ['1'], filter.anded('cary','kayo').map(&:source_id).sort
    assert_equal [], filter.anded('cary','kayo', 'easton').map(&:source_id).sort
    assert_equal ['1','2','3'], filter.ored('cary','kayo').map(&:source_id).sort
  end
end

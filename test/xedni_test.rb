require 'minitest/autorun'
require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','xedni'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','redis_daemon'))

ENV["XEDNI_LOGGING"] = 'true'
ENV.delete("XEDNI_LOGGING")

class TestXedni < MiniTest::Unit::TestCase
  def setup
    #RedisDaemon.daemonize("restart")
    $redis = Redis.new(:port => 6380)
    $redis.flushall
  end
  def teardown
    $redis = nil
    #RedisDaemon.daemonize("stop")
  end

  def test_crud_records
    rec_id = Xedni.create("rec_1", {:foo=>['foo1','foo2',:foo3]}, {:val=>100, :fear=>0})
    assert_equal "rec_1", rec_id
    assert_equal ['foo1','foo2','foo3'], Xedni.read("rec_1")['collections']['foo']
    assert_equal ['foo1','foo2','foo3'], Xedni.delete("rec_1")['collections']['foo']
    assert_equal false, Xedni.read("rec_1")
  end

  def test_simple_keyword_search
    rec 'mr1', {:a => ['a','b','c']}, :quality=>1.0
    rec 'mr2', {:a => ['b','c','d']}, :quality=>1.0
    rec 'mr3', {:a => ['c','d','e']}, :quality=>1.0
    rec 'mr4', {:a => ['d','e','f']}, :quality=>1.0

    results = Xedni.search([[:a,['a']]])
    assert_equal ['mr1'], results['records']
    results = Xedni.search([[:a,['a','b']]])
    assert_equal ['mr1','mr2'].sort, results['records'].sort
    results = Xedni.search([[:a,['a','b','c']]])
    assert_equal ['mr1','mr2','mr3'].sort, results['records'].sort
  end
  def test_multi_keyword_search
    rec 'mr1', {:a => ['a','b','c'], :b => [1,2,3]}, :quality=>1.0
    rec 'mr2', {:a => ['b','c','d'], :b => [2]},     :quality=>1.0
    rec 'mr3', {:a => ['c','d','e'], :b => [3]},     :quality=>1.0
    rec 'mr4', {:a => ['d','e','f'], :b => [4]},     :quality=>1.0

    results = Xedni.search([[:a,['d']], [:b, [2]]])
    assert_equal ['mr2'].sort, results['records'].sort
    results = Xedni.search([[:a,['d']], [:b,[2,3]]])
    assert_equal ['mr2', 'mr3'].sort, results['records'].sort

    results = Xedni.search([
                [:a, ['d','a']],
                [:b, [2,3]]
    ])
    assert_equal ['mr1','mr2', 'mr3'].sort, results['records'].sort

    # Now we try to search AND'ing a and f, no results
    results = Xedni.search([ [:a, ['a']], [:a, ['f']] ])
    assert_equal [].sort, results['records']

  end
  def test_sorting_by_weights
    rec 'mr2', {:a => ['a']},               {}
    rec 'mr1', {:a => ['a','b']},           {:q=>1.0, :r=>3}
    rec 'mr3', {:a => ['a','b','c']},       {:q=>2.0, :r=>3}
    rec "foo", {:a => ['a','b','c','d']},   {:q=>3.0, :r=>1}

    results = Xedni.search([[:a,['a','b','c','d']]], {:q=>1})
    assert_equal ['foo','mr3','mr1','mr2'], results['records']

    results = Xedni.search([[:a,['a','b','c','d']]], {:q=>1, :r=>5})
    assert_equal ['mr3','mr1','foo','mr2'], results['records']
  end

  def test_floating_00_100_weights
    # Scores come in as 0.00 - 1.00 floats, internally are scaled to 100, and
    # then on the way out are converted back.
    skip("Not Implemented")
  end

  def test_ranges_on_collections_search
    results = Xedni.search([[:ingredients,[1, "-", 4]]])
    skip("Not Implemented")
  end

  def test_limiting_to_records
    results = Xedni.search([[:records,[]]])
    skip("Not Implemented")
  end

  def test_pagination
    results = Xedni.search([], {}, {:page=>1, :per_page=>10})
    skip("Not Implemented")
  end

  private

  def rec(id, keys={}, weights={})
    Xedni.create(id,keys, weights)
  end
end

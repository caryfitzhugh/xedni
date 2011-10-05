require 'minitest/autorun'
require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','xedni'))

class TestRecord < MiniTest::Unit::TestCase
  def test_score_algorithm
    record = Xedni::Record.new("db_record_45", :scores=>{:quality=>1.0, :sweetness=>0.5, :saltiness=>0.3}).save
    assert_equal (1.0 + 0.5 + 0.3) / 3.0, record.score

    assert_equal (1.0) / 1, record.score(:quality=>1.0)

    assert_equal (1.0*0.3 + 0.5*0.5) / 2, record.score(:quality=>0.30, :sweetness=>0.5)
  end
  def test_parsing_input_keywords
    record = Xedni::Record.new("db_record_45")
    assert_equal "xedni:record:db_record_45", record.id

    record = Xedni::Record.new("db_record_45", :keywords=>['apple'])
    assert_equal ["apple"], record.keywords

    record = Xedni::Record.new("db_record_45", :collections=>{:hope=>['1','2','3']}, :keywords=>['apple', 'pear'])
    assert_equal ["apple", "pear"], record.keywords
    hsh = {'hope' =>['1','2','3']}
    assert_equal hsh,    record.collections
  end
  def test_finding_by_keyword
    record1= Xedni::Record.new("1", :keywords=>['apple', 'grape']).save
    record2= Xedni::Record.new("2", :keywords=>['apple', 'pear']).save
    record3= Xedni::Record.new("3", :keywords=>['apple', 'grape']).save
    record3= Xedni::Record.new("4", :keywords=>['foo']).save

    keywords = Xedni::Filter.new('keywords')
    assert_equal ['1','2','3'], keywords.anded('apple').map(&:source_id).sort
    assert_equal ['1','3'],     keywords.anded('grape').map(&:source_id).sort
    assert_equal ['2'],         keywords.anded('pear').map(&:source_id).sort

    assert_equal ['1','2','3'], keywords.ored('pear','grape').map(&:source_id).sort
    assert_equal ['2','4'],     keywords.ored('pear','foo').map(&:source_id).sort
  end
end

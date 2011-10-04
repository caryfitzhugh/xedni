require 'minitest/autorun'
require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','xedni'))

class TestRecord < MiniTest::Unit::TestCase
  def test_parsing_input_keywords
    record = Xedni::Record.new({:id=>"db_record_45"})
    assert_equal "db_record_45", record.id

    record = Xedni::Record.new({:id=>"db_record_45", :keywords=>['apple']})
    assert_equal ["apple"], record.keywords

    record = Xedni::Record.new({:id=>"db_record_45", :collections=>{:hope=>['1','2','3']}, :keywords=>['apple', 'pear']})
    assert_equal ["apple", "pear"], record.keywords
    hsh = {'hope' =>['1','2','3']}
    assert_equal hsh,    record.collections
  end
end

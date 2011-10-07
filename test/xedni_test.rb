require 'minitest/autorun'
require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','xedni'))

class TestXedni < MiniTest::Unit::TestCase
  # TODO
  #  Need to test the adding / removing of records.
  #
  #  Test the searching for things by collection value (keywords too)
  #  with scoring adjustments (and ranked by # of matches too!)
  #  (0 - 100) on all our values.
  #
  #  Only get one level of AND / OR
  #
  #  Add pagination support
  #
  #  Add facetization support!
  def test_create_records
    Xedni.create("rec_1", {:foo=>['foo1','foo2',:foo3]}, {:val=>100, :fear=>0})
  end
end

require 'minitest/autorun'
require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','lib','xedni'))

class TestXedni < MiniTest::Unit::TestCase

  def test_search
    load_records '1' => { :keywords=>['gala','apple'],
                          :collections=>{'type'=>'fruit', 'color'=>'red', 'taste'=>'sweet'},
                          :scores=>{ :sweetness=>1.0, :saltiness=>0.1, :popularity=>1.0}
                        },
                 '2' => { :keywords=>['mango'],
                          :collections=>{'type'=>'fruit', 'color'=>'yellow', 'taste'=>'sweet'},
                          :scores=>{ :sweetness=>0.8, :saltiness=>0.2, :popularity=>0.8}
                        },
                 '3' => { :keywords=>['salted','peanuts'],
                          :collections=>{'type'=>'legume', 'color'=>'brown', 'taste'=>'salty'},
                          :scores=>{ :sweetness=>0.1, :saltiness=>1.0, :popularity=>0.7}
                        },
                 '4' => { :keywords=>['honey','roasted','peanuts'],
                          :collections=>{'type'=>'legume', 'color'=>'orange', 'taste'=>'sweet'},
                          :scores=>{ :sweetness=>0.6, :saltiness=>0.5, :poularity=>0.1}
                        }

    assert_equal ['3','4'], Xedni.search([:and, 'peanuts']).map(&:source_id)
    assert_equal ['1','3','4'], Xedni.search([:or, 'peanuts', 'gala']).map(&:source_id)
    assert_equal [], Xedni.search([:and, 'peanuts', 'gala']).map(&:source_id)
    assert_equal ['1','3','4'], Xedni.search([:or, [:and,'peanuts'],[:and, 'gala']]).map(&:source_id)

    assert_equal ['3','4'], Xedni.search([:or, 'peanuts',{'taste'=>['sweet']}]).map(&:source_id)

    assert_equal ['1','3','4'], Xedni.search([:or, 'peanuts','apple',{'taste'=>['sweet']}]).map(&:source_id)
  end

end

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

    [
      [['3','4'],     [:and, {:keywords=>['peanuts']}]],
      [['1','3','4'], [:or, {:keywords=>['peanuts']},{:keywords=>['gala']}]],
      [[],            [:and, {:keywords=>['peanuts', 'gala']}]],
      [['1','3','4'], [:or, [:and,{:keywords=>['peanuts']}], [:and,{:keywords=>['gala'   ]}]]],
      [['3','4'],     [:or, {:keywords=>['peanuts']},{:taste=>['sweet']}]],
      [['1','3','4'], [:or, {:keywords=>['peanuts']},{:keywords=>['apple']},{'taste'=>['sweet']}]]
    ].each do |should_be, query|
      assert_equal should_be, Xedni.search(query).map(&:source_id)
    end
  end
  def test_facet_counts
    # Need to run Xedni.search([....])
    #
    # Returns the counts correctly? AND btwn facets and ORs ?.... ?
    # This is confusa bibble...
    #
    # Might just have a facets query which takes:
    #
    # keywords, :facets=> { }
    # returns keywords && (facet1 [ a || b || c] && facet2 [ a || b || c])
    #
    # and do all the facet work like that and return
    fail
  end
end

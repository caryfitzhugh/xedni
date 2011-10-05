require 'active_support/all'
require File.expand_path(File.join(File.dirname(__FILE__),'xedni','record'))
require File.expand_path(File.join(File.dirname(__FILE__),'xedni','filter'))
module Xedni
  def self.key_name(*args)
    args.unshift("xedni").join(':')
  end

  # Syntax is a bunch of arrays
  #  TODO write this parser so out come the correct values!
  #   eventually this exact code is shipped to LUA in REDIS, but for now we do it on our side.
  #
  # keywords (or) a,b,c AND collection speed=>'fast'
  # [:and, [:or, 'a','b','c'], {:speed=>['fast']}]
  #
  # keywords (a, b, or C) && d {:speed=>['fast' OR 'medium']}
  # Inside the [] of a collection, it is AND, to make it OR you must hop out into an :or-ray
  # [:and, [:and, :d, [:or, a, b, c]], [:or, {:speed=>['fast']},{:speed=>['medium']}]]
  def self.search(keywords, collections={}, scores=:default)
    records = find_records(keywords, collections)
    score_records(records, scores)
  end

  def self.find_records(keywords, collections)
    keyword_matches = Xedni::Filter.new('keywords').anded(*keywords)
  end

  def self.score_records(records, scores)
    records.sort_by {|record| -1*record.score(scores)}
  end
end

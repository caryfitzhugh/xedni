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
  def self.search(query, scores=:default)
    records = find_records(query)
    score_records(records, scores)
  end

  def self.find_records(query)
    # go over the entries.
    # if it is a string - it's a keyword. Find those keywords
    # if it is a hash - find those collections
    # if it is :and, or :or at the front - then we need to union / intersect the results
    type = query.shift
    records = query.collect do |v|
      case v
      when Hash
        # Could be a Set....
        collection_ids = Array.new
        v.each_pair do |filter_name, filter_keys|
          collection_ids.concat Xedni::Filter.new(filter_name).anded(*filter_keys)
        end
        collection_ids.uniq
      when Array
        find_records(v)
      else
        Xedni::Filter.new('keywords').ored(v)
      end
    end

    records = case type
    when :and
      intersects = records.shift
      records.each do |rec|
        intersects = intersects & rec
      end
      intersects.flatten
    when :or
      records.flatten.uniq
    end
    records
  end

  def self.score_records(records, scores)
    records.sort_by {|record| -1*record.score(scores)}
  end
end

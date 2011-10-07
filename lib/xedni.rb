require 'active_support/all'
require File.expand_path(File.join(File.dirname(__FILE__),'xedni','record'))
require File.expand_path(File.join(File.dirname(__FILE__),'xedni','filter'))
module Xedni
  def self.key_name(*args)
    args.unshift("xedni").join(':')
  end

  # Syntax is a bunch of hashes
  # :keywords =>
  # :collection =>
  # :collection =>
  # :records => [    ]    // Limit it to only these records.
  #
  # Facet returned is each one with 'if you clicked this what would you get?'
  #
  # Scores need to include the # of times it was matched. And by default that is a 1.0 score.
  def self.search(query, scores=:default)
    records, facets = find_records(query)
    score_records(records, scores)
  end

  def self.find_records(query)
    # go over the entries.
    # if it is a string - it's a keyword. Find those keywords
    # if it is a hash - find those collections
    # if it is :and, or :or at the front - then we need to union / intersect the results
    facets = []
    type = query.shift
    records,facets = query.collect do |v|
      case v
      when Hash
        # Could be a Set....
        collection_ids = Array.new
        v.each_pair do |filter_name, filter_keys|
          collection_ids.concat Xedni::Filter.new(filter_name).anded(*filter_keys)
        end
        # Here facets should be the counts of each value, in a hash
        [collection_ids.uniq, facets]
      when Array # Or a sub array
        # Here the facets are just passed back from find_records
        find_records(v)
      else
        raise "What are you doig here? Only arrays and hashes (or :and / :or!)"
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
    [records, facets]
  end

  def self.score_records(records, scores)
    records.sort_by {|record| -1*record.score(scores)}
  end
end

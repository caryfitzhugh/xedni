require 'active_support/all'
require File.expand_path(File.join(File.dirname(__FILE__),'xedni','scripts'))

module Xedni
  def self.key_name(*args)
    args.unshift("xedni").join(':')
  end
  def self.to_lua(hash_or_array)
    if hash_or_array.is_a?(Hash)
      values = []
      hash_or_array.each_pair {|k,v|
        values << "#{k} = #{self.to_lua(v)}"
      }
      "{" + values.join(", ") + "}"
    elsif hash_or_array.is_a?(Array)
      values = hash_or_array.collect {|v| self.to_lua(v) }
      "{" + values.join(", ") + "}"
    elsif hash_or_array.is_a?(String)
      "\"#{hash_or_array}\""
    elsif hash_or_array.is_a?(Symbol)
      "\"#{hash_or_array.to_s}\""
    else
      hash_or_array
    end
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
  def self.create(id, collections, scores)
    self.update(id, collections, scores)
  end
  def self.update(id, collections, scores)
    collection_lua = self.to_lua(collections)
    scores_lua     = self.to_lua(scores)
    Xedni::Scripts.create(id, collection_lua, scores_lua)
  end
  def self.delete(id)

  end
  def self.read(id)

  end
  def self.find_records(query)
    records = facets = {}
    [records, facets]
  end

  def self.score_records(records, scores)
    records.sort_by {|record| -1*record.score(scores)}
  end
end

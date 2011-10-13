require 'active_support/all'
require File.expand_path(File.join(File.dirname(__FILE__),'xedni','scripts'))

module Xedni
  module Log
    def self.debug(*args)
      if ENV['XEDNI_LOGGING']
        Logger.new(STDOUT).debug("Xedni") { args.join("\n") }
      end
    end
  end
  def self.key_name(*args)
    args.unshift("xedni").join(':')
  end
  # Syntax is a bunch of hashes
  # :collections => {   }
  # :records => [    ]    // Limit it to only these records.
  #
  # Facet returned is each one with 'if you clicked this what would you get?'
  #
  # Scores need to include the # of times it was matched. And by default that is a 1.0 score.
  def self.search(query, scores=:default, options={:page=>1, :per_page=>1000})
    response =  Xedni::Scripts.query(:query=>query, :scores=>scores, :options=>options)
  end
  def self.create(id, collections, scores)
    self.update(id, collections, scores)
  end
  def self.update(id, collections, scores)
    Xedni::Scripts.create(:record=>id, :collections=>collections, :scores=>scores)
  end
  def self.read(id)
    Xedni::Scripts.read(:record=>id)
  end
  def self.delete(id)
    Xedni::Scripts.delete(:record=>id)
  end
  def self.find_records(query)
    records = facets = {}
    [records, facets]
  end
end

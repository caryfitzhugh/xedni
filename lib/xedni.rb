# Copyright (C) 2011 by Cary FitzHugh
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'active_support/all'
require File.expand_path(File.join(File.dirname(__FILE__),'xedni','scripts'))
require File.expand_path(File.join(File.dirname(__FILE__),'xedni','log'))
require File.expand_path(File.join(File.dirname(__FILE__),'xedni','connection'))

module Xedni
  class Exception < Exception
  end
  def self.load(count)
    tstart = Time.now
    # Create all the records
    records = (0..count).map do |i|
      { :id => i,
        :attrs=>
          {:a => rand(20) / 1,
           :b => rand(20) / 1,
           :c => rand(20) / 1,
           :d => rand(20) / 1,
           :e => rand(20) / 1,
           :f => rand(20) / 1,
           :g => rand(20) / 1}
      }
    end

    # Populate
    puts 'Populating redis'
    records.each do |record|
      # Add record to records
      Xedni::Connection.connection.sadd 'collections:ids', record[:id]
      # Add to all the collections
      record[:attrs].each_pair do |i,v|
        Xedni::Connection.connection.sadd "collections:attr_#{i}:keys", v
        Xedni::Connection.connection.sadd "collections:attr_#{i}:#{v}", record[:id]
      end
      Xedni::Connection.connection.sadd  "record:#{record[:id]}:keys", 'a'
      Xedni::Connection.connection.sadd  "record:#{record[:id]}:keys", 'b'
      Xedni::Connection.connection.sadd  "record:#{record[:id]}:keys", 'c'
      Xedni::Connection.connection.sadd  "record:#{record[:id]}:keys", 'd'
      Xedni::Connection.connection.sadd  "record:#{record[:id]}:keys", 'e'
      Xedni::Connection.connection.sadd  "record:#{record[:id]}:keys", 'f'

      Xedni::Connection.connection.hmset "record:#{record[:id]}",
                   "a", record[:attrs][:a],
                   "b", record[:attrs][:b],
                   "c", record[:attrs][:c],
                   "d", record[:attrs][:d],
                   "e", record[:attrs][:e],
                   "f", record[:attrs][:f]

    end
    puts "\n#{records.size} Records in redis in #{Time.now - tstart}"
  end
  def self.benchmark
    # Do the query
    tstart= Time.now
    res = Xedni::Scripts.benchmark("a"=>rand(20)/1, "b"=>rand(20)/1, "c" => rand(20)/1, "d" => rand(20)/1, "e"=>rand(20)/1, "f"=>rand(20)/1)
    tend = Time.now
    [res, tend-tstart]
  end

  # Syntax is a bunch of hashes
  # :collections => {   }
  # :records => [    ]    // Limit it to only these records.
  #
  # Facet returned is each one with 'if you clicked this what would you get?'
  #
  # Scores need to include the # of times it was matched. And by default that is a 1.0 score.
  def self.query(query, weights=:default, options={:page=>1, :per_page=>1000})
    self.search(query, weights, options)
  end
  def self.search(query, weights=:default, options={:page=>1, :per_page=>1000})
    response =  Xedni::Scripts.query(:query=>query, :weights=>weights, :options=>options)
  end

  def self.create(id, collections, weights)
    self.update(id, collections, weights)
  end
  def self.update(id, collections, weights)
    Xedni::Scripts.create(:record=>id, :collections=>collections, :weights=>weights)
  end
  def self.read(id)
    Xedni::Scripts.read(:record=>id)
  end
  def self.delete(id)
    Xedni::Scripts.delete(:record=>id)
  end
  def self.reset
    Xedni::Connection.connection.flushall
  end
end

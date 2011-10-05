module Xedni
  class Record
    attr :keywords, :collections
    def self.find(id)
      rec = Xedni::Record.new(id.split(":").last)
      rec.load
      rec
    end
    def initialize(id,attrs={})
      @id = id
      @keywords    = (attrs[:keywords] || [] ).map(&:to_s)
      @collections = (attrs[:collections] || {}).stringify_keys
      @scores      = (attrs[:scores] || {}).stringify_keys
    end
    def source_id
      @id
    end
    def id
      Xedni.key_name('record', @id)
    end
    def load
      v = $redis.hgetall id
      @keywords = ActiveSupport::JSON.decode(v['keywords'])
      @scores = ActiveSupport::JSON.decode(v['scores'])
      @collections = ActiveSupport::JSON.decode(v['collections'])
    end
    def score(score_weights=:default)
      if (score_weights == :default)
        if @scores.blank?
          0.0
        else
          nums = @scores.map {|name, val| val}
          num = nums.sum
          denom = @scores.keys.count
          num / denom
        end
      else
          nums = score_weights.collect do |score_key, score_weight|
            @scores[score_key.to_s].to_f * score_weight.to_f
          end
          num = nums.sum
          denom = score_weights.keys.count
          num / denom
      end
    end
    def save
      $redis.hmset id,
        'keywords', ActiveSupport::JSON.encode(@keywords),
        'scores', ActiveSupport::JSON.encode(@scores),
        'collections', ActiveSupport::JSON.encode(@collections)
      # Now save all the keywords
      keywords = Xedni::Filter.new('keywords')
      @keywords.each do |keyword|
        keywords.add(keyword, self)
      end
      collections = Xedni::Filter.new('collections')
      @collections.each do |collection|
        collections.add(collection, self)
      end
      self
    end
  end
end

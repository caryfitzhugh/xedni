module Xedni
  class Filter
    def initialize(name)
      @name = name
    end

    def anded(*keys)
      keys = $redis.sinter(*keys.collect {|k| filter_name(k) })
      keys.map {|id| Xedni::Record.find(id) }
    end
    def ored(*keys)
      ($redis.sunion(*keys.collect {|k| filter_name(k) })).map {|id| Xedni::Record.find(id) }
    end

    def add(filter_key, record_or_id)
      record_id = get_id(record_or_id)
      $redis.sadd keys_name, filter_key
      $redis.sadd filter_name(filter_key), record_id
    end

    def remove(filter_key, record_or_id)
      record_id = get_id(record_or_id)
      $redis.srem filter_name(filter_key), record_id

      # If it's empty - remove from _keys
      if ($redis.smembers(filter_name(filter_key)).empty?)
        $redis.srem keys_name, filter_key
      end
    end

    def keys
      $redis.smembers keys_name
    end

    private
    def get_id(record_or_id)
      case record_or_id
      when Xedni::Record
        record_or_id.id
      else
        record_or_id
      end
    end
    def filter_name(key)
      Xedni.key_name('filter',@name,key)
    end
    def keys_name
      Xedni.key_name('filter',@name,'_keys')
    end
  end
end

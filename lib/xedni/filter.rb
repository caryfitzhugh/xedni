module Xedni
  class Filter
    def initialize(name)
      @name = name
    end

    def add(filter_key, record_id)
      $redis.sadd keys_name, filter_key
      $redis.sadd filter_name(filter_key), record_id
    end

    def remove(filter_key, record_id)
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

    def filter_name(key)
      Xedni.key_name('filter',@name,key)
    end
    def keys_name
      Xedni.key_name('filter',@name,'_keys')
    end
  end
end

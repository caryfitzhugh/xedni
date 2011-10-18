## The Connection manager for redis.
module Xedni::Connection
  @@connection = nil
  def self.connection
    if @@connection
      @@connection
    else
      raise Xedni::Exception.new("No Redis Connection created yet")
    end
  end
  def self.connect(conn_opts = {})
    @@connection = Redis.new(conn_opts)
  end
end

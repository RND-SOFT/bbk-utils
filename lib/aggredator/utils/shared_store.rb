require 'logger'
require 'active_support/cache'

module Aggredator
  class SharedStore
    def initialize(redis, key, logger=nil, &block)
      @store = build_store(redis)
      @store.logger = logger || ::Logger.new(STDOUT)
      @key = key
      @default = block
    end
  
    def fetch
      @store.fetch(@key) do
        @default.call
      end
    end
  
    def write value
      @store.write(@key, value)
    end
  
    def clear
      @store.delete(@key)
    end
  
    def build_store(redis)
      if redis.is_a?(String)
        ActiveSupport::Cache::RedisCacheStore.new(host: redis, connect_timeout: 1, read_timeout: 1, write_timeout: 1)
      else
        ActiveSupport::Cache::RedisCacheStore.new(redis: redis, connect_timeout: 1, read_timeout: 1, write_timeout: 1)
      end
    end
  end  
end

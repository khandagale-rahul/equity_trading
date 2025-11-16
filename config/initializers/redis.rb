# frozen_string_literal: true

# Global Redis client configuration
# Access via: Redis.client (thread-safe connection pool)

module Redis
  class << self
    def client
      @redis_config ||= RedisClient.config(
        url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
        reconnect_attempts: 3,
        timeout: 5.0
      )

      @client ||= @redis_config.new_pool(timeout: 0.5, size: Integer(ENV.fetch("RAILS_MAX_THREADS", 5)))
    end

    # Reset the client connection (useful for testing or reconnection scenarios)
    def reset_client!
      @client&.close
      @client = nil
    end

    # Convenience method for safe Redis operations with error handling
    def safe_call(command, *args)
      client.call(command, *args)
    rescue Redis::BaseError => e
      Rails.logger.error("[Redis] Command failed: #{command} #{args.inspect} - #{e.message}")
      nil
    end
  end
end

# frozen_string_literal: true

# Global Redis client configuration
# Access via: Redis.client or $redis (global variable for backward compatibility)

module Redis
  class << self
    def client
      @client ||= RedisClient.config(
        url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
        reconnect_attempts: 3,
        timeout: 5.0
      ).new_client
    end

    # Reset the client connection (useful for testing or reconnection scenarios)
    def reset_client!
      @client&.close
      @client = nil
    end
  end
end

# Global variable for convenience
$redis = Redis.client

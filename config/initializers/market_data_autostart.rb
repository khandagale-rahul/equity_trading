Rails.application.config.after_initialize do
  next if Rails.env.test?

  # Skip if running in Sidekiq worker process
  next if defined?(Sidekiq) && Sidekiq.server?

  # Start service after server boots if during trading hours
  current_time = Time.current

  if (1..5).include?(current_time.wday) &&
    current_time.hour >= 9 && current_time.hour < 16
    Rails.logger.info "[MarketData] Server restart detected during trading hours. Auto-starting WebSocket service..."
    Upstox::StartWebsocketConnectionJob.perform_async
  end
end

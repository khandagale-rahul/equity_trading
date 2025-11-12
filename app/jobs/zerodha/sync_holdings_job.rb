module Zerodha
  class SyncHoldingsJob
    include Sidekiq::Job
    include JobLogger

    queue_as :default

    def perform(**options)
      setup_job_logger
      log_info "[Zerodha] Starting holdings sync at #{Time.current}"

      configs = ApiConfiguration.zerodha
      configs = configs.where(user_id: options[:user_id]) if options[:user_id].presence

      configs.each do |api_config|
        service = Zerodha::SyncHoldingsService.new
        summary = service.sync(api_config)

        if summary[:total_configs] == 0
          log_warn "[Zerodha] #{summary[:message]}"
          return
        end

        log_info "[Zerodha] Found #{summary[:total_configs]} Zerodha API configuration(s)"

        summary[:results].each do |result|
          if result[:status] == :success
            log_info "[Zerodha] SUCCESS: User #{result[:user_name]} (ID: #{result[:user_id]}) - #{result[:message]}"
          else
            log_error "[Zerodha] ERROR: User #{result[:user_name]} (ID: #{result[:user_id]}) - #{result[:message]}"
          end
        end

        log_info "[Zerodha] Holdings sync completed. Success: #{summary[:success_count]}, Errors: #{summary[:error_count]}"
      end
    end
  end
end

class ScheduleStrategyExecutionJob
  include Sidekiq::Job
  include JobLogger

  queue_as :default

  def perform
    setup_job_logger
    log_info "Starting execution of strategy entry rules at #{Time.current}"

    deployed_strategies = Strategy.deployed
    log_info "Found #{deployed_strategies.count} deployed strategies"

    deployed_strategies.each do |strategy|
      if strategy.type == "ScreenerBasedStrategy"
        hour, min = strategy.screener_execution_time.split(":")
        strategy.reset_fields!
        ScanEntryRuleJob.perform_at(Time.now.change(hour: hour.to_i, min: min.to_i), strategy.id, { scanner_check: true }.to_json)
      else
        ScanEntryRuleJob.perform_async(strategy.id)
      end

      log_info "Scheduled strategy: #{strategy.name} (ID: #{strategy.id}, Type: #{strategy.type})"
    end

    log_info "Completed execution of all strategy entry rules"
  rescue StandardError => e
    log_error "Error executing strategy entry rules: #{e.message}"
    log_error e.backtrace.join("\n")
    raise
  end
end

class ScheduleStrategyExecutionJob
  include Sidekiq::Job
  include JobLogger

  queue_as :default

  def perform
    setup_job_logger
    log_info "Starting execution of strategy entry rules at #{Time.current}"

    executable_strategies = Strategy.executable
    log_info "Found #{executable_strategies.count} executable strategies"

    executable_strategies.each do |strategy|
      ScanEntryRuleJob.perform_async(strategy.id)
      log_info "Scheduled strategy: #{strategy.name} (ID: #{strategy.id}, Type: #{strategy.type})"
    end

    log_info "Completed execution of all strategy entry rules"
  rescue StandardError => e
    log_error "Error executing strategy entry rules: #{e.message}"
    log_error e.backtrace.join("\n")
    raise
  end
end

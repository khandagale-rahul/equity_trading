class ExecuteStrategyEntryRulesJob
  include Sidekiq::Job
  include JobLogger

  queue_as :default

  def perform
    setup_job_logger
    log_info "Starting execution of strategy entry rules at #{Time.current}"

    executable_strategies = Strategy.executable
    log_info "Found #{executable_strategies.count} executable strategies"

    executable_strategies.each do |strategy|
      log_info "Processing strategy: #{strategy.name} (ID: #{strategy.id}, Type: #{strategy.type})"

      non_re_enter_master_instrument_ids = strategy.entered_master_instrument_ids.tally.select { |_, count| count >= strategy.re_enter }.keys
      master_instrument_ids = strategy.master_instrument_ids - non_re_enter_master_instrument_ids

      filtered_master_instrument_ids = strategy.evaluate_entry_rule(master_instrument_ids)
      filtered_master_instrument_ids.each do |master_instrument_id|
        PlaceOrderJob.perform_now(strategy.id, master_instrument_id)
      end

      log_info "Completed processing strategy: #{strategy.name}, filtered instruments count: #{filtered_master_instrument_ids.count}"
      log_info "Master instrument IDs: #{filtered_master_instrument_ids.inspect}"
    end

    log_info "Completed execution of all strategy entry rules"
  rescue StandardError => e
    log_error "Error executing strategy entry rules: #{e.message}"
    log_error e.backtrace.join("\n")
    raise
  end
end

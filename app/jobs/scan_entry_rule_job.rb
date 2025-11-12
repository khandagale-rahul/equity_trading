class ScanEntryRuleJob
  include Sidekiq::Job
  include JobLogger

  queue_as :default

  def perform(strategy_id, options = "{}")
    setup_job_logger
    log_info "=" * 70
    log_info "Started job for strategy: #{strategy_id}"

    strategy = Strategy.find_by(id: strategy_id)
    unless strategy
      log_warn "Strategy #{strategy_id} not found, exiting job"
      return
    end
    log_info "Found strategy: #{strategy.name} (type: #{strategy.type})"

    options = JSON.parse(options).with_indifferent_access
    log_info "Parsed options: scanner_check=#{options[:scanner_check]}"

    if strategy.type == "ScreenerBasedStrategy" && options[:scanner_check]
      log_info "Running screener scan for ScreenerBasedStrategy"
      strategy.scan
      log_info "Screener scan completed, found #{strategy.master_instrument_ids.count} instruments"
    end

    if strategy.entered_master_instrument_ids.uniq.count >= strategy.daily_max_entries
      log_info "Daily max entries (#{strategy.daily_max_entries}) reached, resetting entered_master_instrument_ids"
      strategy.update(entered_master_instrument_ids: [])
      log_info "Job completed after resetting entries"
      return
    end

    non_re_enter_master_instrument_ids = strategy.entered_master_instrument_ids.tally.select { |_, count| count >= strategy.re_enter }.keys
    log_info "Filtered out #{non_re_enter_master_instrument_ids.count} instruments that reached re-enter limit"

    master_instrument_ids = strategy.master_instrument_ids - non_re_enter_master_instrument_ids
    log_info "Candidate instruments for entry evaluation: #{master_instrument_ids.count}"

    if master_instrument_ids.empty?
      log_info "No candidate instruments available, exiting job"
      return
    end

    log_info "Evaluating entry rules for #{master_instrument_ids.count} instruments"
    filtered_master_instrument_ids = strategy.evaluate_entry_rule(master_instrument_ids)
    log_info "Entry rule evaluation completed: #{filtered_master_instrument_ids.count} instruments matched"

    filtered_master_instrument_ids.each do |master_instrument_id|
      strategy.entered_master_instrument_ids << master_instrument_id
      log_info "Added master_instrument_id #{master_instrument_id} to entered list"

      if strategy.save
        log_info "Initiating order placement for master_instrument_id #{master_instrument_id}"
        strategy.initiate_place_order(master_instrument_id)
        log_info "Order placement initiated successfully for master_instrument_id #{master_instrument_id}"
      else
        log_error "Failed to save strategy after adding master_instrument_id #{master_instrument_id}: #{strategy.errors.full_messages.join(', ')}"
      end
    end

    log_info "Scheduling next job execution in 1 minute"
    ScanEntryRuleJob.perform_at((Time.now + 1.minutes).change(sec: 0), strategy_id, { scanner_check: false }.to_json)
    log_info "Job completed successfully"
  rescue StandardError => e
    log_error "Failed to complete job for Strategy #{strategy_id}: #{e.message}"
    log_error "Backtrace: #{e.backtrace.first(5).join("\n")}"
  end
end

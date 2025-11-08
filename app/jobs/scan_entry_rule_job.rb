class ScanEntryRuleJob
  include Sidekiq::Job
  include JobLogger

  queue_as :default

  def perform(strategy_id)
    setup_job_logger

    strategy = Strategy.find_by(id: strategy_id)
    return unless strategy
    if strategy.entered_master_instrument_ids.uniq.count >= strategy.daily_max_entries
      self.update(entered_master_instrument_ids: [])
      return
    end

    non_re_enter_master_instrument_ids = strategy.entered_master_instrument_ids.tally.select { |_, count| count >= strategy.re_enter }.keys
    master_instrument_ids = strategy.master_instrument_ids - non_re_enter_master_instrument_ids
    return if master_instrument_ids.empty?

    filtered_master_instrument_ids = strategy.evaluate_entry_rule(master_instrument_ids)

    filtered_master_instrument_ids.each do |master_instrument_id|
      strategy.entered_master_instrument_ids << master_instrument_id

      if strategy.save
        strategy.initiate_place_order(master_instrument_id)
      end
    end

    ScanEntryRuleJob.perform_at((Time.now + 1.minutes).change(sec: 0), strategy_id)
  rescue StandardError => e
    log_error "Failed to place order for Strategy #{strategy_id} on Master Instrument #{master_instrument_id}: #{e.message}"
  end
end

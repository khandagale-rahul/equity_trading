class ScanExitRuleJob
  include Sidekiq::Job
  include JobLogger

  queue_as :default
  sidekiq_options lock: :until_executed, on_conflict: :reject

  def perform(place_order_id)
    setup_job_logger

    entry_order = Order.entry.find_by(id: order_id)
    return unless entry_order

    exit_order = entry_order.exit_order
    if exit_order && exit_order.undiscarded?
    else
      exit_order = entry_order.initiate_exit_order
      exit_order.save
    end

    filtered_master_instrument_ids = exit_order.strategy.evaluate_exit_rule([ order.master_instrument_id ])

    if filtered_master_instrument_ids.include?(order.master_instrument_id)
      exit_order.exit_at_current_price
    else
      ScanExitRuleJob.perform_at((Time.now + 1.minutes).change(sec: 0), strategy_id)
    end
  rescue StandardError => e
    log_error "Failed to close order for Strategy #{strategy_id} on Master Instrument #{master_instrument_id}: #{e.message}"
  end
end

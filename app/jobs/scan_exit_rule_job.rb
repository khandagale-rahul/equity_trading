class ScanExitRuleJob
  include Sidekiq::Job
  include JobLogger

  queue_as :default
  sidekiq_options lock: :until_executed, on_conflict: :reject

  def perform(entry_order_id)
    setup_job_logger

    entry_order = Order.entry.find_by(id: entry_order_id)
    return unless entry_order

    exit_order = entry_order.exit_order
    return if exit_order.completed? || exit_order.cancelled?

    if exit_order && exit_order.undiscarded?
      entry_order.update_order_status unless entry_order.completed?
      exit_order.update_order_status
    else
      exit_order = entry_order.initiate_exit_order
      exit_order.save
    end

    filtered_master_instrument_ids = exit_order.strategy.evaluate_exit_rule([ exit_order.master_instrument_id ])

    if filtered_master_instrument_ids.include?(exit_order.master_instrument_id)
      exit_order.exit_at_current_price
    else
      ScanExitRuleJob.perform_at((Time.now + 1.minutes).change(sec: 0), entry_order_id)
    end
  rescue StandardError => e
    log_error "Failed to close order for Strategy #{entry_order_id}: #{e.message}"
  end
end

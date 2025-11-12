class ScanExitRuleJob
  include Sidekiq::Job
  include JobLogger

  queue_as :default
  sidekiq_options lock: :until_executed, on_conflict: :reject

  def perform(entry_order_id)
    setup_job_logger
    logs = []

    entry_order = Order.entry.find_by(id: entry_order_id)
    if entry_order
      exit_order = entry_order.exit_order

      if exit_order.present? && (exit_order.completed? || exit_order.cancelled?)
        logs << [ :log_warn, "Already been in #{exit_order.status.humanize} state. Terminating" ]
      else
        if exit_order.present? && exit_order.undiscarded?
          unless entry_order.completed?
            entry_order.update_order_status
            logs << [ :log_info, "Updated Entry order" ]
          end
          exit_order.update_order_status
          logs << [ :log_info, "Updated Exit order" ]
        else
          exit_order = entry_order.initiate_exit_order
          exit_order.save
          logs << [ :log_info, "Created Exit order" ]
        end

        logs << [ :log_info, "Evaluating Exit Rule" ]
        filtered_master_instrument_ids = exit_order.strategy.evaluate_exit_rule([ exit_order.master_instrument_id ])

        if filtered_master_instrument_ids.include?(exit_order.master_instrument_id)
          logs << [ :log_info, "Satisfied Exit Rule" ]
          exit_order.exit_at_current_price
        else
          logs << [ :log_info, "Rescheduled after 1 minute" ]
          ScanExitRuleJob.perform_at((Time.now + 1.minutes).change(sec: 0), entry_order_id)
        end
      end
    else
      logs << [ :log_warn, "Entry Order is not present" ]
    end

    handle_logs(logs)
    nil
  rescue StandardError => e
    log_error "Failed to close order for Strategy #{entry_order_id}: #{e.message}"
  end

  private

  def handle_logs(logs)
    logs.each do |log|
      send(log[0], log[1])
    end
  end
end

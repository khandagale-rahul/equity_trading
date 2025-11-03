class PlaceOrderJob
  include Sidekiq::Job
  include JobLogger

  queue_as :default

  def perform(strategy_id, master_instrument_id)
    setup_job_logger
    log_info "Placing order for Strategy #{strategy_id} on Master Instrument #{master_instrument_id}"
    strategy = Strategy.find_by(id: strategy_id)
    return unless strategy

    push_notification = strategy.push_notifications.new(
      user_id: strategy.user.id,
      item_type: "MasterInstrument",
      item_id: master_instrument_id,
      data: { message: "Placing order for Strategy #{strategy_id} on Master Instrument #{master_instrument_id}" }
    )

    CloseOrderJob.perform_now(strategy_id, master_instrument_id)

    if push_notification.save
      log_info "Push notification created with ID #{push_notification.id}"
    else
      log_error "Failed to create push notification: #{push_notification.errors.full_messages.join(', ')}"
    end
  rescue StandardError => e
    log_error "Failed to place order for Strategy #{strategy_id} on Master Instrument #{master_instrument_id}: #{e.message}"
  end
end

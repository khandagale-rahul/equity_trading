class CloseOrderJob
  include Sidekiq::Job
  include JobLogger

  queue_as :default

  def perform(strategy_id, master_instrument_id)
    setup_job_logger

    strategy = Strategy.find_by(id: strategy_id)
    return unless strategy

    log_info "Closing order for Strategy #{strategy_id} on Master Instrument #{master_instrument_id}"

    Thread.new do
      strategy.evaluate_exit_rule([ master_instrument_id ])
    end
  rescue StandardError => e
    log_error "Failed to close order for Strategy #{strategy_id} on Master Instrument #{master_instrument_id}: #{e.message}"
  end
end

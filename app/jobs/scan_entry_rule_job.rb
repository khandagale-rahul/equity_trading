class ScanEntryRuleJob
  include Sidekiq::Job
  include JobLogger

  queue_as :default

  def perform(strategy_id, options = "{}")
    logs = []

    setup_job_logger
    logs << [ :log_info, "strategy_id: #{strategy_id} " + ("=" * 70) ]

    strategy = Strategy.find_by(id: strategy_id)
    if strategy
      options = JSON.parse(options).with_indifferent_access

      strategy.scan if strategy.type == "ScreenerBasedStrategy" && options[:scanner_check]
      in_trading_hours = Time.now.hour.between?(9, 14)

      if in_trading_hours && strategy.entered_master_instrument_ids.uniq.count < strategy.daily_max_entries
        non_re_enter_master_instrument_ids = strategy.entered_master_instrument_ids.tally.select { |_, count| count >= strategy.re_enter }.keys

        master_instrument_ids = strategy.master_instrument_ids - non_re_enter_master_instrument_ids

        if master_instrument_ids.present?
          strategy.evaluate_entry_rule(master_instrument_ids) do |filtered_master_instrument_ids|
            logs << [ :log_info, "#{filtered_master_instrument_ids.count} stock/s satisfied entry rule" ]

            filtered_master_instrument_ids.each do |master_instrument_id|
              strategy.entered_master_instrument_ids << master_instrument_id

              if strategy.save
                strategy.initiate_place_order(master_instrument_id)
                logs << [ :log_info, "Initiated Order for #{master_instrument_id}" ]
              else
                logs << [ :log_error, "Failed to save strategy after adding master_instrument_id #{master_instrument_id}: #{strategy.errors.full_messages.join(', ')}" ]
              end
            end
          end

          ScanEntryRuleJob.perform_at(
            (Time.now + 1.minutes).change(sec: 0),
            strategy_id, { scanner_check: false }.to_json
          )
          logs << [ :log_info, "Scheduled scan after 1 minute" ]
        else
          logs << [ :log_warn, "No instrument available to trade. No further scan" ]
        end
      else
        strategy.update(entered_master_instrument_ids: [])
        logs << [ :log_warn, "Strategy #{strategy_id} Reached max entries. No further scan" ]
      end
    else
      logs << [ :log_warn, "Strategy #{strategy_id} not found, exiting scan" ]
    end

    handle_logs(logs)
  rescue StandardError => e
    log_error "Failed to complete job for Strategy #{strategy_id}: #{e.message}"
    log_error "Backtrace: #{e.backtrace.first(5).join("\n")}"
  end

  private

  def handle_logs(logs)
    logs.each do |log|
      send(log[0], log[1])
    end
  end
end

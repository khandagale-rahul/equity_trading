class SyncInstrumentHistoryJob
  include Sidekiq::Job

  queue_as :default

  def perform(unit: "days", interval: 1, days_back: 1, intraday: true)
    Upstox::SyncInstrumentHistoryJob.perform_async(unit: "days", interval: 1, days_back: 1, intraday: false)

    Upstox::SyncInstrumentHistoryJob.perform_at(
      Time.now.change(hour: 9, min: 15),
      unit: "days", interval: 1, days_back: 1, intraday: true
    )
  end
end

module TechnicalIndicators
  module Close
    extend ActiveSupport::Concern

    def close(unit, interval, number_of_candles)
      self.instrument.instrument_histories.where(
        unit: unit,
        interval: interval
      ).order(date: :desc)
      .limit(number_of_candles)
      .pluck(:close)
    end
  end
end

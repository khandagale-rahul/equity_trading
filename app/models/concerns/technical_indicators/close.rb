module TechnicalIndicators
  module Close
    extend ActiveSupport::Concern

    def close(unit, interval, number_of_candles = 0)
      key = "#{self.master_instrument.id}_#{unit}_#{interval}_#{number_of_candles}"

      @calculated_data[key] ||= self.master_instrument.instrument_histories.where(
        unit: unit,
        interval: interval
      ).order(date: :desc)
      .offset(number_of_candles)
      .first

      @calculated_data[key].close
    end
  end
end

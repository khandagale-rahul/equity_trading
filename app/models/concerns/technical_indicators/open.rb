module TechnicalIndicators
  module Open
    extend ActiveSupport::Concern

    def open(unit, interval, candle_number = 0)
      key = "#{self.master_instrument.id}_#{unit}_#{interval}_#{candle_number}"

      @calculated_data[key] ||= self.master_instrument.instrument_histories.where(
        unit: unit,
        interval: interval
      ).order(date: :desc)
      .offset(candle_number)
      .first

      @calculated_data[key].open
    end
  end
end

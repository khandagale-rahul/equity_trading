module TechnicalIndicators
  module Open
    extend ActiveSupport::Concern

    def open(unit, interval, number_of_candles)
     self.master_instrument.instrument_histories.where(
        unit: unit,
        interval: interval
      ).order(date: :desc)
      .offset(number_of_candles-1)
      .first
      .open
    end
  end
end

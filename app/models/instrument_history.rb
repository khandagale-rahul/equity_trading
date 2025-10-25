class InstrumentHistory < ApplicationRecord
  belongs_to :master_instrument

  enum :unit, { minute: 1, hour: 2, day: 3, week: 4, month: 5 }

  def previous_candle
    InstrumentHistory.where(
      master_instrument_id: master_instrument_id,
      unit: unit,
      interval: interval
    ).where("date < ?", date).order(date: :desc).first
  end
end

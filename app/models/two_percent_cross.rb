class TwoPercentCross < Setup
  def self.initiate
    MasterInstrument.each do |master_instrument|
      TwoPercentCross.rules(master_instrument)
    end
  end

  # Shortlisting Rules
  # 1. yesterday gain should be less than 1%
  # 2. yesterday high should be less than 2% than day before yesterday close
  # 3. Open should be less than 1%
  def rules
    "(previous_candle_close - previous_candle_open)/previous_candle_open * 100 < 1 &&" \
    "(previous_candle_high - day_before_previous_candle_close)/day_before_previous_candle_close * 100 < 2 &&" \
    "(current_candle_open - previous_candle_close)/previous_candle_close * 100 < 1"
  end

  def self.is_satisfy_rule?(master_instrument)
    current_candle = master_instrument.last_instrument_history
    return false unless current_candle

    previous_candle = current_candle.previous_candle
    day_before_previous_candle = previous_candle.previous_candle

    previous_candle_close = previous_candle.close.to_f
    previous_candle_open = previous_candle.open.to_f
    previous_candle_high = previous_candle.high.to_f
    day_before_previous_candle_close = day_before_previous_candle.close.to_f
    current_candle_open = current_candle.open.to_f

    eval self.rules
  end
end

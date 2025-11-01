class ScreenerBasedStrategy < Strategy
  [
    :screener_id,
    :screener_execution_time,
    :master_instrument_ids
  ].each do |param|
    define_method(param) do
      parameters[param.to_s]
    end

    define_method("#{param}=") do |value|
      self.parameters ||= {}
      self.parameters[param.to_s] = value
    end
  end

  def screener
    Screener.find_by(id: screener_id)
  end

  def master_instruments
    MasterInstrument.where(id: master_instrument_ids)
  end
end

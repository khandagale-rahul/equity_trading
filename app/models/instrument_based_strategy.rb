class InstrumentBasedStrategy < Strategy
  def master_instrument_ids
    parameters["master_instrument_ids"] || []
  end

  def master_instrument_ids=(ids)
    cleaned_ids = Array(ids).reject(&:blank?).map(&:to_i)
    self.parameters = {}
    self.parameters["master_instrument_ids"] = cleaned_ids
  end

  def master_instrument_ids
    parameters["master_instrument_ids"] || []
  end

  def master_instruments
    MasterInstrument.where(id: master_instrument_ids)
  end
end

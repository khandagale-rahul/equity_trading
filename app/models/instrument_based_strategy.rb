class InstrumentBasedStrategy < Strategy
  validates :master_instrument_ids,
            presence: true

  def master_instruments
    MasterInstrument.where(id: master_instrument_ids)
  end
end

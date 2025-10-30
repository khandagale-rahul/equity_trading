class InstrumentsController < ApplicationController
  def index
    @master_instruments = MasterInstrument.joins(:upstox_instrument).includes(
      :last_instrument_history, :upstox_instrument, :zerodha_instrument
    ).order(name: :asc)
  end
end

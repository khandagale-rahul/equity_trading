class InstrumentBasedStrategiesController < StrategiesController
  def show
    @master_instruments = @strategy.master_instruments
  end
end

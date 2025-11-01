class StrategiesController < ApplicationController
  before_action :set_strategy, only: %i[ show edit update destroy ]

  def index
    @strategies = current_user.strategies
  end

  def show
  end

  def new
    @strategy = Strategy.new
    set_prerequisites
  end

  def edit
    set_prerequisites
  end

  def create
    @strategy = current_user.strategies.new(strategy_params)

    if @strategy.save
      redirect_to @strategy, notice: "Strategy was successfully created."
    else
      set_prerequisites
      render :new, status: :unprocessable_content
    end
  end

  def update
    @strategy.type = strategy_params[:type]

    if @strategy.update(strategy_params)
      redirect_to @strategy, notice: "Strategy was successfully updated.", status: :see_other
    else
      set_prerequisites
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @strategy.destroy!
    redirect_to strategies_path, notice: "Strategy was successfully destroyed.", status: :see_other
  end

  private
    def set_strategy
      @strategy = current_user.strategies.find(params.expect(:id))
    end

    def strategy_params
      if params.dig(:strategy, :type) == "InstrumentBasedStrategy"
        params.require(:strategy).permit(
          :name,
          :type,
          :description,
          master_instrument_ids: []
        )
      elsif params.dig(:strategy, :type) == "ScreenerBasedStrategy"
        params.require(:strategy).permit(
          :name,
          :type,
          :description,
          :screener_id,
        )
      else
        params.require(:strategy).permit(
          :name,
          :type,
          :description,
          :rules
        )
      end
    end

    def set_prerequisites
      @master_instruments = MasterInstrument.all.order(:name)
      @screeners = Screener.all.order(:name)
    end
end

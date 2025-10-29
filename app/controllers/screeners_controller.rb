class ScreenersController < ApplicationController
  before_action :set_screener, only: %i[ show edit update destroy scan ]

  def index
    @screeners = current_user.screeners
  end

  def show
    @master_instruments = @screener.master_instruments
  end

  def new
    @screener = Screener.new
  end

  def edit
  end

  def create
    @screener = current_user.screeners.new(screener_params)

    if @screener.save
      redirect_to @screener, notice: "Screener was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @screener.update(screener_params)
      redirect_to @screener, notice: "Screener was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @screener.destroy!
    redirect_to screeners_path, notice: "Screener was successfully destroyed.", status: :see_other
  end

  def scan
    @screener.scan
    @master_instruments = @screener.master_instruments
    redirect_to @screener, notice: "Scanned Successfully"
  end

  private
    def set_screener
      @screener = current_user.screeners.find(params.expect(:id))
    end

    def screener_params
      params.expect(screener: [
        :name,
        :user_id,
        :active,
        :rules
      ])
    end
end

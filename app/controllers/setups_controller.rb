class SetupsController < ApplicationController
  before_action :set_setup, only: %i[ show edit update destroy ]

  # GET /setups
  def index
    @setups = current_user.setups
  end

  # GET /setups/1
  def show
  end

  # GET /setups/new
  def new
    @setup = Setup.new
  end

  # GET /setups/1/edit
  def edit
  end

  # POST /setups
  def create
    @setup = current_user.setups.new(setup_params)

    if @setup.save
      redirect_to @setup, notice: "Setup was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /setups/1
  def update
    if @setup.update(setup_params)
      redirect_to @setup, notice: "Setup was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /setups/1
  def destroy
    @setup.destroy!
    redirect_to setups_path, notice: "Setup was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_setup
      @setup = current_user.setups.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def setup_params
      params.expect(setup: [
        :name,
        :user_id,
        :shortlisted_instruments,
        :active,
        :trades_per_day,
        :rules
      ])
    end
end

module Zerodha
  class PostbackController < ActionController::Base
    def receive
      user = User.find_by(id: params[:user_id])
      render json: { error: "User not found" }, status: :not_found and return unless user

      api_configuration = user.api_configurations.zerodha.find_by(id: params[:api_config_id])
      render json: { error: "API configuration not found" }, status: :not_found and return unless api_configuration

      postback_data = JSON.parse(request.body.read).with_indifferent_access
      render json: { error: "No postback data received" }, status: :bad_request and return unless postback_data.present?

      log_postback(user.id, api_configuration.id, postback_data)

      service = PostbackService.new(
        postback_data: postback_data,
        api_configuration: api_configuration
      )
      result = service.process

      if result[:success]
        render json: {
          success: true,
          message: result[:message],
          order_id: result[:order]&.id
        }, status: :ok
      else
        render json: {
          success: false,
          error: result[:error]
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Postback Controller Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        success: false,
        error: "Internal server error"
      }, status: :internal_server_error
    end

    private

    def log_postback(user_id, api_config_id, postback_data)
      Rails.logger.info "=" * 80
      Rails.logger.info "Zerodha Postback Received"
      Rails.logger.info "User ID: #{user_id}"
      Rails.logger.info "API Config ID: #{api_config_id}"
      Rails.logger.info "Order ID: #{postback_data[:order_id] || postback_data['order_id']}"
      Rails.logger.info "Status: #{postback_data[:status] || postback_data['status']}"
      Rails.logger.info "Trading Symbol: #{postback_data[:tradingsymbol] || postback_data['tradingsymbol']}"
      Rails.logger.info "Data: #{postback_data.inspect}"
      Rails.logger.info "=" * 80
    end
  end
end

module Zerodha
  class PostbackService
    attr_reader :postback_data, :api_configuration

    def initialize(postback_data:, api_configuration:)
      @postback_data = postback_data
      @api_configuration = api_configuration
    end

    def verify_checksum
      return false unless postback_data[:checksum].present?

      postback_data[:checksum] == generate_checksum
    end

    def process
      unless verify_checksum
        return { success: false, error: "Invalid checksum - postback authentication failed" }
      end

      order = ZerodhaOrder.find_by(broker_order_id: postback_data[:order_id], user_id: api_configuration.user_id)
      if order
        order.update_order_details(orpostback_datader)
        { success: true, message: "Order updated successfully" }
      else
        { success: false, error: "Failed to create or find order" }
      end
    rescue => e
      { success: false, error: e.message }
    end

    private

    def generate_checksum
      order_id = postback_data[:order_id]
      order_timestamp = postback_data[:order_timestamp]

      return nil unless order_id && order_timestamp && api_configuration.api_secret

      checksum_string = "#{order_id}#{order_timestamp}#{api_configuration.api_secret}"
      Digest::SHA256.hexdigest(checksum_string)
    end
  end
end

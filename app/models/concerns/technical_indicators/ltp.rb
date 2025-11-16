module TechnicalIndicators
  module Ltp
    extend ActiveSupport::Concern

    MARKET_OPEN_TIME = { hour: 9, min: 15 }.freeze
    MARKET_CLOSE_TIME = { hour: 15, min: 30 }.freeze

    def ltp
      if market_hours?
        fetch_ltp_from_redis
      else
        close("day", 1, 0)
      end
    end

    private

      def market_hours?
        now = Time.current
        return false unless now.strftime("%A").in?(%w[Monday Tuesday Wednesday Thursday Friday])

        market_open = now.change(MARKET_OPEN_TIME)
        market_close = now.change(MARKET_CLOSE_TIME)

        now.between?(market_open, market_close)
      end

      def fetch_ltp_from_redis
        Redis.client.call("GET", self.master_instrument.exchange_token).to_f
      rescue Redis::BaseError => e
        Rails.logger.error("[LTP] Redis fetch failed for #{self.master_instrument.exchange_token}: #{e.message}")
        close("day", 1, 0) || 0.0
      end
  end
end

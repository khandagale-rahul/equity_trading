module TechnicalIndicators
  module Ltp
    extend ActiveSupport::Concern

    def ltp
      if Time.now.between?(Time.now.change(hour: 9, min: 15), Time.now.change(hour: 15, min: 30))
        fetch_ltp_from_redis
      else
        close("day", 1, 0)
      end
    end

    private

      def fetch_ltp_from_redis
        $redis.call("GET", self.master_instrument.exchange_token).to_f
      end
  end
end

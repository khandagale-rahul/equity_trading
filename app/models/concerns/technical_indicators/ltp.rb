module TechnicalIndicators
  module Ltp
    extend ActiveSupport::Concern

    def ltp
      if Time.now.between?(Time.now.change(hour: 9, min: 15), Time.now.change(hour: 15, min: 30))
        # self.master_instrument.ltp
      else
        close("day", 1, 0)
      end
    end
  end
end

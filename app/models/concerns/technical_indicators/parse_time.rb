module TechnicalIndicators
  module ParseTime
    extend ActiveSupport::Concern

    def parse_time(hour, minute, second = 0)
      Time.now.change(hour: hour, minute: minute, second: second)
    end
  end
end

module TechnicalIndicators
  module ParseTime
    extend ActiveSupport::Concern

    def parse_time(hour, minute, second = 0)
      Time.now.change(hour: hour.to_i, minute: minute.to_i, second: second.to_i)
    end
  end
end

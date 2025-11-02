module TechnicalIndicators
  module CurrentTime
    extend ActiveSupport::Concern

    def current_time
      Time.now
    end
  end
end

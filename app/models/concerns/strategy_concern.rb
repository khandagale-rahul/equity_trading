module StrategyConcern
  extend ActiveSupport::Concern

  include TechnicalIndicators::Close
  include TechnicalIndicators::Open
  include TechnicalIndicators::High
  include TechnicalIndicators::Low
  include TechnicalIndicators::Ltp
  include TechnicalIndicators::CurrentTime
  include TechnicalIndicators::ParseTime
end

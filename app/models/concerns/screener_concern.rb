module ScreenerConcern
  extend ActiveSupport::Concern

  include TechnicalIndicators::Close
  include TechnicalIndicators::Open
  include TechnicalIndicators::High
  include TechnicalIndicators::Low
  include TechnicalIndicators::Ltp
end

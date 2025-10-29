module ScreenerConcern
  extend ActiveSupport::Concern

  include TechnicalIndicators::Close
  include TechnicalIndicators::Open
  include TechnicalIndicators::High
end

class Holding < ApplicationRecord
  has_paper_trail

  enum :broker, { zerodha: 1, upstox: 2, angel_one: 3 }
  belongs_to :user
end

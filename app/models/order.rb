class Order < ApplicationRecord
  enum :trade_action, { entry: 1, exit: 2 }

  belongs_to :user
  belongs_to :strategy
  belongs_to :master_instrument
  belongs_to :instrument, polymorphic: true, optional: true

  has_many :push_notifications, as: :item
end

class Order < ApplicationRecord
  has_paper_trail

  include AASM
  include Discard::Model

  enum :trade_action, { entry: 1, exit: 2 }

  belongs_to :user
  belongs_to :strategy
  belongs_to :master_instrument
  belongs_to :instrument, polymorphic: true, optional: true

  has_one :exit_order,
          -> { where(trade_action: ::Order.trade_actions["exit"]) },
          class_name: "Order",
          foreign_key: :entry_order_id
  has_one :entry_order,
          -> { where(trade_action: ::Order.trade_actions["entry"]) },
          class_name: "Order",
          primary_key: :entry_order_id,
          foreign_key: :id

  has_many :push_notifications, as: :item

  def push_to_broker
    if strategy.only_simulate
      ScanExitRuleJob.perform_async(id)
    end
  end

  def notify_about_initiation
    if strategy.only_simulate
      messages = []
      messages << "Simulating #{self.class.to_s.underscore.humanize}. Entry Price: #{price}"

      self.push_notifications.create(
        user_id: user_id,
        message: messages.join(" ")
      )
    end
  end

  def parse_timestamp(timestamp_string)
    return nil unless timestamp_string.present?

    Time.zone.parse(timestamp_string)
  rescue => e
    Rails.logger.error "Failed to parse timestamp: #{timestamp_string} - #{e.message}"
    nil
  end
end

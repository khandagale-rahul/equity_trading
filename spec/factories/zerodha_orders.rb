FactoryBot.define do
  factory :zerodha_order, parent: :order, class: 'ZerodhaOrder' do
    association :user
    association :strategy
    association :master_instrument, factory: [ :master_instrument, :with_zerodha ]
    trade_action { :entry }
    tradingsymbol { "RELIANCE" }
    exchange { "NSE" }
    variety { ZerodhaOrder::VARIETY_REGULAR }
    order_type { ZerodhaOrder::ORDER_TYPE_MARKET }
    product { ZerodhaOrder::PRODUCT_MIS }
    validity { ZerodhaOrder::VALIDITY_DAY }
    transaction_type { ZerodhaOrder::TRANSACTION_TYPE_BUY }
    quantity { 1 }
    price { 100.0 }
    trigger_price { 0 }

    trait :entry do
      trade_action { :entry }
      transaction_type { ZerodhaOrder::TRANSACTION_TYPE_BUY }
    end

    trait :exit do
      trade_action { :exit }
      transaction_type { ZerodhaOrder::TRANSACTION_TYPE_SELL }
    end

    trait :limit_order do
      order_type { ZerodhaOrder::ORDER_TYPE_LIMIT }
      price { 100.0 }
    end

    trait :stop_loss do
      order_type { ZerodhaOrder::ORDER_TYPE_SL }
      price { 95.0 }
      trigger_price { 98.0 }
    end
  end
end

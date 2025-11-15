FactoryBot.define do
  factory :order do
    association :user
    association :strategy
    association :master_instrument
    trade_action { :entry }
    price { 100.0 }
    quantity { 1 }

    trait :entry do
      trade_action { :entry }
    end

    trait :exit do
      trade_action { :exit }
    end
  end
end

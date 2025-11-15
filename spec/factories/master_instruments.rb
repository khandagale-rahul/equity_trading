FactoryBot.define do
  factory :master_instrument do
    name { Faker::Company.name }
    exchange { "NSE" }
    sequence(:exchange_token) { |n| n }
    ltp { 100.0 }

    trait :with_zerodha do
      association :zerodha_instrument
    end

    trait :with_upstox do
      association :upstox_instrument
    end

    trait :with_both do
      association :zerodha_instrument
      association :upstox_instrument
    end
  end
end

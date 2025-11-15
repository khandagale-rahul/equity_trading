FactoryBot.define do
  factory :screener do
    association :user
    name { Faker::Lorem.words(number: 3).join(' ') }
    rules { "true" }
    active { true }
    scanned_master_instrument_ids { [] }

    trait :inactive do
      active { false }
    end

    trait :with_complex_rule do
      rules { "master_instrument.ltp > 100" }
    end

    trait :with_master_instrument do
      after(:build) do |screener|
        create(:master_instrument, :with_upstox)
      end
    end
  end
end

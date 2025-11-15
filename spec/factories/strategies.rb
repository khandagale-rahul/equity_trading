FactoryBot.define do
  factory :strategy do
    association :user
    name { Faker::Lorem.words(number: 3).join(' ') }
    entry_rule { "true" }
    exit_rule { "true" }
    master_instrument_ids { [] }
    deployed { false }
    only_simulate { true }

    after(:build) do |strategy|
      strategy.type ||= 'RuleBasedStrategy'
    end

    trait :deployed do
      deployed { true }
    end

    trait :not_simulated do
      only_simulate { false }
    end
  end
end

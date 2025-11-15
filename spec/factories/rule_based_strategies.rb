FactoryBot.define do
  factory :rule_based_strategy, parent: :strategy, class: 'RuleBasedStrategy' do
    association :user
    name { Faker::Lorem.words(number: 3).join(' ') }
    entry_rule { "true" }
    exit_rule { "true" }
    parameters { { rules: "master_instrument.ltp > 100" } }
  end
end

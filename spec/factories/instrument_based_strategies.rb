FactoryBot.define do
  factory :instrument_based_strategy, parent: :strategy, class: 'InstrumentBasedStrategy' do
    association :user
    name { Faker::Lorem.words(number: 3).join(' ') }
    entry_rule { "true" }
    exit_rule { "true" }
    master_instrument_ids { [ create(:master_instrument).id ] }
  end
end

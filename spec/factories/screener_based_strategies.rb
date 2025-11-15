FactoryBot.define do
  factory :screener_based_strategy, parent: :strategy, class: 'ScreenerBasedStrategy' do
    association :user
    name { Faker::Lorem.words(number: 3).join(' ') }
    entry_rule { "true" }
    exit_rule { "true" }
    parameters { { screener_id: create(:screener, :with_master_instrument).id, screener_execution_time: "09:30" } }
  end
end

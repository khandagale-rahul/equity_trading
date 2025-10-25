FactoryBot.define do
  factory :setup do
    type { "" }
    user { nil }
    shortlisted_instruments { "" }
    active { false }
    trades_per_day { 1 }
  end
end

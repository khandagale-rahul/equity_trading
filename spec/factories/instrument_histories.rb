FactoryBot.define do
  factory :instrument_history do
    association :master_instrument
    unit { :day }
    interval { 1 }
    date { Time.zone.now }
    open { 100.0 }
    high { 105.0 }
    low { 95.0 }
    close { 102.0 }
    volume { 10000 }
  end
end

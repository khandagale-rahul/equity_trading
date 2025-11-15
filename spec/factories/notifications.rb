FactoryBot.define do
  factory :notification do
    association :user
    association :item, factory: :strategy
    message { "random Message" }

    after(:build) do |notification|
      notification.type ||= 'PushNotification'
    end
  end
end

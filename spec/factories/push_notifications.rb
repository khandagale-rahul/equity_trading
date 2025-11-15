FactoryBot.define do
  factory :push_notification, parent: :notification, class: 'PushNotification' do
    association :user
    association :item, factory: :strategy
    message { "random Message" }
  end
end

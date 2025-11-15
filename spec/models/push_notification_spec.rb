require 'rails_helper'

RSpec.describe PushNotification, type: :model do
  describe "inheritance" do
    it "inherits from Notification" do
      expect(PushNotification.superclass).to eq(Notification)
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:item) }
  end

  describe "AASM states inherited from Notification" do
    let(:push_notification) { create(:push_notification) }

    it "has initial state as sent" do
      expect(push_notification.status).to eq("sent")
      expect(push_notification.sent?).to be true
    end

    it "can transition to delivered state" do
      push_notification.deliver!
      expect(push_notification.delivered?).to be true
    end

    it "can transition to read state" do
      push_notification.deliver!
      push_notification.read!
      expect(push_notification.read?).to be true
    end
  end

  describe "STI type" do
    let(:push_notification) { create(:push_notification) }

    it "has type set to PushNotification" do
      expect(push_notification.type).to eq("PushNotification")
    end

    it "is queryable using STI" do
      create(:push_notification)
      create(:notification, type: 'OtherNotification')
      expect(PushNotification.count).to eq(1)
      expect(Notification.count).to eq(2)
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:push_notification)).to be_valid
    end

    it "creates a valid push notification" do
      expect(create(:push_notification)).to be_persisted
    end
  end
end

require 'rails_helper'

RSpec.describe Notification, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:item) }
  end

  describe "polymorphic association" do
    let(:user) { create(:user) }
    let(:strategy) { create(:strategy, user: user, entry_rule: "true", exit_rule: "true") }

    it "can be associated with a Strategy" do
      notification = create(:notification, user: user, item: strategy)
      expect(notification.item).to eq(strategy)
      expect(notification.item_type).to eq("Strategy")
    end
  end

  describe "AASM states" do
    let(:notification) { create(:notification) }

    it "has initial state as sent" do
      expect(notification.status).to eq("sent")
      expect(notification.sent?).to be true
    end

    it "can transition to delivered state" do
      notification.deliver!
      expect(notification.delivered?).to be true
    end

    it "can transition to read state" do
      notification.deliver!
      notification.read!
      expect(notification.read?).to be true
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:notification)).to be_valid
    end

    it "creates a valid notification" do
      expect(create(:notification)).to be_persisted
    end
  end
end

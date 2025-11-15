require 'rails_helper'

RSpec.describe Order, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:strategy) }
    it { is_expected.to belong_to(:master_instrument) }
    it { is_expected.to belong_to(:instrument).optional }
    it { is_expected.to have_many(:push_notifications) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:trade_action).with_values(entry: 1, exit: 2) }
  end

  describe "enum trade_action" do
    it "can be set to entry" do
      order = create(:order, trade_action: :entry)
      expect(order.trade_action).to eq("entry")
      expect(order.entry?).to be true
    end

    it "can be set to exit" do
      order = create(:order, trade_action: :exit)
      expect(order.trade_action).to eq("exit")
      expect(order.exit?).to be true
    end
  end

  describe "soft delete with Discard" do
    let(:order) { create(:order) }

    it "includes Discard::Model" do
      expect(Order.included_modules).to include(Discard::Model)
    end

    it "can be discarded" do
      order.discard
      expect(order.discarded?).to be true
      expect(order.discarded_at).to be_present
    end

    it "can be kept (undiscarded)" do
      order.discard
      order.undiscard
      expect(order.discarded?).to be false
      expect(order.discarded_at).to be_nil
    end
  end

  describe "exit order associations" do
    let(:user) { create(:user) }
    let(:strategy) { create(:strategy, user: user) }
    let(:master_instrument) { create(:master_instrument) }
    let(:entry_order) { create(:order, :entry, user: user, strategy: strategy, master_instrument: master_instrument) }

    it "can have an exit order" do
      exit_order = create(:order, :exit, user: user, strategy: strategy, master_instrument: master_instrument, entry_order_id: entry_order.id)
      expect(entry_order.exit_order).to eq(exit_order)
    end

    it "exit order can reference entry order" do
      exit_order = create(:order, :exit, user: user, strategy: strategy, master_instrument: master_instrument, entry_order_id: entry_order.id)
      expect(exit_order.entry_order).to eq(entry_order)
    end
  end

  describe "#push_to_broker" do
    context "when strategy only_simulate is true" do
      let(:strategy) { create(:strategy, only_simulate: true) }
      let(:order) { create(:order, strategy: strategy) }

      it "enqueues ScanExitRuleJob" do
        order.push_to_broker
        expect(ScanExitRuleJob).to have_enqueued_sidekiq_job
      end
    end

    context "when strategy only_simulate is false" do
      let(:strategy) { create(:strategy, only_simulate: false) }
      let(:order) { create(:order, strategy: strategy) }

      it "does not enqueue ScanExitRuleJob" do
        order.push_to_broker
        expect(ScanExitRuleJob).not_to have_enqueued_sidekiq_job(order.id)
      end
    end
  end

  describe "#parse_timestamp" do
    let(:order) { create(:order) }

    it "parses valid timestamp string" do
      timestamp_string = "2025-01-15 10:30:00"
      result = order.parse_timestamp(timestamp_string)
      expect(result).to be_a(Time)
      expect(result.strftime("%Y-%m-%d %H:%M:%S")).to eq(timestamp_string)
    end

    it "returns nil for invalid timestamp" do
      result = order.parse_timestamp("invalid-timestamp")
      expect(result).to be_nil
    end

    it "returns nil for nil input" do
      result = order.parse_timestamp(nil)
      expect(result).to be_nil
    end

    it "returns nil for empty string" do
      result = order.parse_timestamp("")
      expect(result).to be_nil
    end
  end

  describe "AASM" do
    it "includes AASM" do
      expect(Order.included_modules).to include(AASM)
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:order)).to be_valid
    end

    it "creates a valid order" do
      expect(create(:order)).to be_persisted
    end

    it "creates entry order with trait" do
      order = create(:order, :entry)
      expect(order.entry?).to be true
    end

    it "creates exit order with trait" do
      order = create(:order, :exit)
      expect(order.exit?).to be true
    end
  end
end

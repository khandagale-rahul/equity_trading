require 'rails_helper'

RSpec.describe ScreenerBasedStrategy, type: :model do
  describe "inheritance" do
    it "inherits from Strategy" do
      expect(ScreenerBasedStrategy.superclass).to eq(Strategy)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:entry_rule) }
    it { is_expected.to validate_presence_of(:exit_rule) }

    it "validates screener_id presence" do
      strategy = build(:screener_based_strategy, parameters: { screener_execution_time: "09:30" })
      expect(strategy).not_to be_valid
      expect(strategy.errors[:screener_id]).to include("must be present")
    end

    it "validates screener_execution_time presence" do
      screener = create(:screener, :with_master_instrument)
      strategy = build(:screener_based_strategy, parameters: { screener_id: screener.id })
      expect(strategy).not_to be_valid
      expect(strategy.errors[:screener_execution_time]).to include("must be present")
    end

    it "validates screener_execution_time format" do
      screener = create(:screener, :with_master_instrument)
      strategy = build(:screener_based_strategy, parameters: { screener_id: screener.id, screener_execution_time: "invalid" })
      expect(strategy).not_to be_valid
      expect(strategy.errors[:screener_execution_time]).to include("is not valid")
    end

    it "accepts valid time format HH:MM" do
      screener = create(:screener, :with_master_instrument)
      strategy = build(:screener_based_strategy, parameters: { screener_id: screener.id, screener_execution_time: "09:30" })
      expect(strategy).to be_valid
    end
  end

  describe "parameter accessors" do
    let(:screener) { create(:screener, :with_master_instrument) }
    let(:strategy) { create(:screener_based_strategy, parameters: { screener_id: screener.id, screener_execution_time: "10:15" }) }

    it "provides screener_id accessor" do
      expect(strategy.screener_id).to eq(screener.id)
    end

    it "provides screener_execution_time accessor" do
      expect(strategy.screener_execution_time).to eq("10:15")
    end

    it "allows setting screener_id" do
      new_screener = create(:screener, :with_master_instrument)
      strategy.screener_id = new_screener.id
      expect(strategy.screener_id).to eq(new_screener.id)
    end

    it "allows setting screener_execution_time" do
      strategy.screener_execution_time = "11:30"
      expect(strategy.screener_execution_time).to eq("11:30")
    end
  end

  describe "#screener" do
    let(:screener) { create(:screener, :with_master_instrument) }
    let(:strategy) { create(:screener_based_strategy, parameters: { screener_id: screener.id, screener_execution_time: "09:30" }) }

    it "returns the associated screener" do
      expect(strategy.screener).to eq(screener)
    end

    it "returns nil when screener doesn't exist" do
      strategy.screener_id = 999999
      expect(strategy.screener).to be_nil
    end
  end

  describe "#scan" do
    let(:screener) { create(:screener, :with_master_instrument) }
    let(:master_instrument1) { create(:master_instrument, :with_upstox) }
    let(:master_instrument2) { create(:master_instrument, :with_upstox) }
    let(:strategy) { create(:screener_based_strategy, parameters: { screener_id: screener.id, screener_execution_time: "09:30" }) }

    before do
      allow(Redis.client).to receive(:call).and_return(nil)
      screener.update(scanned_master_instrument_ids: [ master_instrument1.id, master_instrument2.id ])
    end

    it "updates master_instrument_ids from screener results" do
      strategy.scan
      expect(strategy.master_instrument_ids).to include(master_instrument1.id, master_instrument2.id)
    end

    it "saves the strategy" do
      expect { strategy.scan }.to change { strategy.reload.updated_at }
    end

    context "when screener is not present" do
      let(:strategy) { create(:screener_based_strategy, parameters: { screener_id: 999999, screener_execution_time: "09:30" }) }

      it "does not update master_instrument_ids" do
        original_ids = strategy.master_instrument_ids
        strategy.scan
        expect(strategy.master_instrument_ids).to eq(original_ids)
      end
    end
  end

  describe "#reset_fields!" do
    let(:screener) { create(:screener, :with_master_instrument) }
    let(:strategy) do
      create(:screener_based_strategy,
             parameters: { screener_id: screener.id, screener_execution_time: "09:30" },
             master_instrument_ids: [ 1, 2, 3 ],
             entered_master_instrument_ids: [ 1, 2 ],
             close_order_ids: [ 10, 20 ])
    end

    it "resets master_instrument_ids to empty array" do
      strategy.reset_fields!
      expect(strategy.reload.master_instrument_ids).to eq([])
    end

    it "resets entered_master_instrument_ids to empty array" do
      strategy.reset_fields!
      expect(strategy.reload.entered_master_instrument_ids).to eq([])
    end

    it "resets close_order_ids to empty array" do
      strategy.reset_fields!
      expect(strategy.reload.close_order_ids).to eq([])
    end
  end

  describe "STI type" do
    let(:strategy) { create(:screener_based_strategy) }

    it "has type set to ScreenerBasedStrategy" do
      expect(strategy.type).to eq("ScreenerBasedStrategy")
    end

    it "is queryable using STI" do
      strategy
      expect(ScreenerBasedStrategy.count).to eq(1)
      expect(Strategy.count).to eq(1)
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:screener_based_strategy)).to be_valid
    end

    it "creates a valid screener based strategy" do
      expect(create(:screener_based_strategy)).to be_persisted
    end
  end
end

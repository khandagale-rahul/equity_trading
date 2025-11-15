require 'rails_helper'

RSpec.describe InstrumentBasedStrategy, type: :model do
  describe "inheritance" do
    it "inherits from Strategy" do
      expect(InstrumentBasedStrategy.superclass).to eq(Strategy)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:master_instrument_ids) }
    it { is_expected.to validate_presence_of(:entry_rule) }
    it { is_expected.to validate_presence_of(:exit_rule) }
  end

  describe "#master_instruments" do
    let(:master_instrument1) { create(:master_instrument) }
    let(:master_instrument2) { create(:master_instrument) }
    let(:strategy) { create(:instrument_based_strategy, master_instrument_ids: [ master_instrument1.id, master_instrument2.id ]) }

    it "returns master instruments by stored IDs" do
      expect(strategy.master_instruments).to include(master_instrument1, master_instrument2)
    end

    it "returns only instruments matching the stored IDs" do
      other_instrument = create(:master_instrument)
      expect(strategy.master_instruments).not_to include(other_instrument)
    end
  end

  describe "STI type" do
    let(:strategy) { create(:instrument_based_strategy) }

    it "has type set to InstrumentBasedStrategy" do
      expect(strategy.type).to eq("InstrumentBasedStrategy")
    end

    it "is queryable using STI" do
      create(:instrument_based_strategy)
      expect(InstrumentBasedStrategy.count).to eq(1)
      expect(Strategy.count).to eq(1)
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:instrument_based_strategy)).to be_valid
    end

    it "creates a valid instrument based strategy" do
      expect(create(:instrument_based_strategy)).to be_persisted
    end

    it "requires master_instrument_ids" do
      strategy = build(:instrument_based_strategy, master_instrument_ids: [])
      expect(strategy).not_to be_valid
      expect(strategy.errors[:master_instrument_ids]).to include("can't be blank")
    end
  end
end

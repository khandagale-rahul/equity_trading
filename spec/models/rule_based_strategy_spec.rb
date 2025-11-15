require 'rails_helper'

RSpec.describe RuleBasedStrategy, type: :model do
  describe "inheritance" do
    it "inherits from Strategy" do
      expect(RuleBasedStrategy.superclass).to eq(Strategy)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:entry_rule) }
    it { is_expected.to validate_presence_of(:exit_rule) }
  end

  describe "parameter accessors" do
    let(:strategy) { create(:rule_based_strategy, parameters: { rules: "master_instrument.ltp > 150" }) }

    it "provides rules accessor" do
      expect(strategy.rules).to eq("master_instrument.ltp > 150")
    end

    it "allows setting rules" do
      strategy.rules = "master_instrument.ltp < 100"
      expect(strategy.rules).to eq("master_instrument.ltp < 100")
    end

    it "stores rules in parameters jsonb field" do
      strategy.rules = "new_rule"
      expect(strategy.parameters["rules"]).to eq("new_rule")
    end
  end

  describe "STI type" do
    let(:strategy) { create(:rule_based_strategy) }

    it "has type set to RuleBasedStrategy" do
      expect(strategy.type).to eq("RuleBasedStrategy")
    end

    it "is queryable using STI" do
      create(:rule_based_strategy)
      expect(RuleBasedStrategy.count).to eq(1)
      expect(Strategy.count).to eq(1)
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:rule_based_strategy)).to be_valid
    end

    it "creates a valid rule based strategy" do
      expect(create(:rule_based_strategy)).to be_persisted
    end

    it "creates strategy with rules in parameters" do
      strategy = create(:rule_based_strategy)
      expect(strategy.parameters["rules"]).to be_present
    end
  end
end

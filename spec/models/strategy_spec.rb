require 'rails_helper'

RSpec.describe Strategy, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:push_notifications) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:entry_rule) }
    it { is_expected.to validate_presence_of(:exit_rule) }
  end

  describe "concerns" do
    it "includes StrategyConcern" do
      expect(Strategy.included_modules).to include(StrategyConcern)
    end

    it "includes RuleEvaluationConcern" do
      expect(Strategy.included_modules).to include(RuleEvaluationConcern)
    end
  end

  describe "PaperTrail" do
    it "has paper trail enabled" do
      expect(Strategy.paper_trail_options?).to be true
    end

    it "creates versions on update" do
      strategy = create(:strategy, name: "Original Strategy")
      expect { strategy.update(name: "Updated Strategy") }.to change { strategy.versions.count }.by(1)
    end
  end

  describe "scopes" do
    describe ".deployed" do
      let!(:deployed_strategy) { create(:strategy, deployed: true) }
      let!(:undeployed_strategy) { create(:strategy, deployed: false) }

      it "returns only deployed strategies" do
        expect(Strategy.deployed).to include(deployed_strategy)
        expect(Strategy.deployed).not_to include(undeployed_strategy)
      end
    end
  end

  describe "#master_instruments" do
    let(:master_instrument1) { create(:master_instrument) }
    let(:master_instrument2) { create(:master_instrument) }
    let(:strategy) { create(:strategy, master_instrument_ids: [ master_instrument1.id ]) }

    it "returns master instruments by IDs" do
      expect(strategy.master_instruments).to include(master_instrument1)
      expect(strategy.master_instruments).not_to include(master_instrument2)
    end

    it "accepts custom instrument IDs" do
      result = strategy.master_instruments([ master_instrument2.id ])
      expect(result).to include(master_instrument2)
      expect(result).not_to include(master_instrument1)
    end
  end

  describe "#evaluate_entry_rule" do
    let(:master_instrument) { create(:master_instrument, :with_upstox, ltp: 150.0) }
    let(:strategy) { create(:strategy, master_instrument_ids: [ master_instrument.id ], entry_rule: "true") }

    before do
      allow($redis).to receive(:call).and_return(nil)
    end

    it "evaluates entry rule for instruments" do
      result = strategy.evaluate_entry_rule
      expect(result).to be_an(Array)
    end

    context "with filtering rule" do
      let(:strategy) { create(:strategy, master_instrument_ids: [ master_instrument.id ], entry_rule: "master_instrument.ltp > 100") }

      it "returns matching instrument IDs" do
        result = strategy.evaluate_entry_rule
        expect(result).to include(master_instrument.id)
      end
    end

    context "with non-matching rule" do
      let(:strategy) { create(:strategy, master_instrument_ids: [ master_instrument.id ], entry_rule: "master_instrument.ltp > 200") }

      it "returns empty array" do
        result = strategy.evaluate_entry_rule
        expect(result).to be_empty
      end
    end
  end

  describe "#evaluate_exit_rule" do
    let(:master_instrument) { create(:master_instrument, :with_upstox, ltp: 150.0) }
    let(:strategy) { create(:strategy, master_instrument_ids: [ master_instrument.id ], exit_rule: "true") }

    before do
      allow($redis).to receive(:call).and_return(nil)
    end

    it "evaluates exit rule for instruments" do
      result = strategy.evaluate_exit_rule
      expect(result).to be_an(Array)
    end

    context "with filtering rule" do
      let(:strategy) { create(:strategy, master_instrument_ids: [ master_instrument.id ], exit_rule: "master_instrument.ltp < 160") }

      it "returns matching instrument IDs" do
        result = strategy.evaluate_exit_rule
        expect(result).to include(master_instrument.id)
      end
    end
  end

  describe "#validate_entry_rule" do
    context "with valid entry rule" do
      it "allows simple true rule" do
        strategy = build(:strategy, entry_rule: "true", exit_rule: "true")
        expect(strategy).to be_valid
      end
    end

    context "with dangerous patterns" do
      it "rejects system command execution" do
        strategy = build(:strategy, entry_rule: "system('ls')", exit_rule: "true")
        expect(strategy).not_to be_valid
        expect(strategy.errors[:entry_rule]).to include("contains potentially dangerous code pattern")
      end

      it "rejects eval" do
        strategy = build(:strategy, entry_rule: "eval('code')", exit_rule: "true")
        expect(strategy).not_to be_valid
        expect(strategy.errors[:entry_rule]).to include("contains potentially dangerous code pattern")
      end
    end
  end

  describe "#validate_exit_rule" do
    context "with dangerous patterns" do
      it "rejects system command execution" do
        strategy = build(:strategy, entry_rule: "true", exit_rule: "system('ls')")
        expect(strategy).not_to be_valid
        expect(strategy.errors[:exit_rule]).to include("contains potentially dangerous code pattern")
      end
    end
  end

  describe "attr_accessor :master_instrument" do
    let(:strategy) { create(:strategy) }
    let(:master_instrument) { create(:master_instrument) }

    it "can set and get master_instrument" do
      strategy.master_instrument = master_instrument
      expect(strategy.master_instrument).to eq(master_instrument)
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:strategy)).to be_valid
    end

    it "creates a valid strategy" do
      expect(create(:strategy)).to be_persisted
    end

    it "creates deployed strategy with trait" do
      strategy = create(:strategy, :deployed)
      expect(strategy.deployed).to be true
    end

    it "creates non-simulated strategy with trait" do
      strategy = create(:strategy, :not_simulated)
      expect(strategy.only_simulate).to be false
    end
  end
end

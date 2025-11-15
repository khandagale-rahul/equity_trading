require 'rails_helper'

RSpec.describe Screener, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:rules) }
  end

  describe "concerns" do
    it "includes ScreenerConcern" do
      expect(Screener.included_modules).to include(ScreenerConcern)
    end

    it "includes RuleEvaluationConcern" do
      expect(Screener.included_modules).to include(RuleEvaluationConcern)
    end
  end

  describe "PaperTrail" do
    it "has paper trail enabled" do
      expect(Screener.paper_trail_options?).to be true
    end

    it "creates versions on update" do
      screener = create(:screener, :with_master_instrument, name: "Original Name")
      expect { screener.update(name: "Updated Name") }.to change { screener.versions.count }.by(1)
    end
  end

  describe "#validate_rules_syntax" do
    context "with valid rules" do
      it "allows simple true rule" do
        screener = build(:screener, :with_master_instrument, rules: "true")
        expect(screener).to be_valid
      end

      it "allows comparison rules" do
        screener = build(:screener, :with_master_instrument, rules: "master_instrument.ltp > 100")
        expect(screener).to be_valid
      end
    end

    context "with dangerous patterns" do
      it "rejects system command execution" do
        screener = build(:screener, :with_master_instrument, rules: "system('ls')")
        expect(screener).not_to be_valid
        expect(screener.errors[:rules]).to include("contains potentially dangerous code pattern")
      end

      it "rejects file operations" do
        screener = build(:screener, :with_master_instrument, rules: "File.read('/etc/passwd')")
        expect(screener).not_to be_valid
        expect(screener.errors[:rules]).to include("contains potentially dangerous code pattern")
      end

      it "rejects database write operations" do
        screener = build(:screener, :with_master_instrument, rules: "User.create(name: 'test')")
        expect(screener).not_to be_valid
        expect(screener.errors[:rules]).to include("contains potentially dangerous code pattern")
      end

      it "rejects eval" do
        screener = build(:screener, :with_master_instrument, rules: "eval('malicious code')")
        expect(screener).not_to be_valid
        expect(screener.errors[:rules]).to include("contains potentially dangerous code pattern")
      end
    end

    context "with syntax errors" do
      it "rejects invalid syntax" do
        screener = build(:screener, :with_master_instrument, :with_master_instrument, rules: "master_instrument.ltp >")
        screener.valid?
        expect(screener).not_to be_valid
        expect(screener.errors[:rules]).to include("is invalid")
      end
    end
  end

  describe "#scan" do
    let(:user) { create(:user) }
    let(:screener) { create(:screener, user: user, rules: "true") }
    let!(:master_instrument1) { create(:master_instrument, :with_upstox, ltp: 150.0) }
    let!(:master_instrument2) { create(:master_instrument, :with_upstox, ltp: 200.0) }

    it "scans all master instruments" do
      result = screener.scan
      expect(result).to be_an(Array)
    end

    it "updates scanned_master_instrument_ids" do
      screener.scan
      expect(screener.scanned_master_instrument_ids).to be_an(Array)
    end

    it "updates scanned_at timestamp" do
      expect { screener.scan }.to change { screener.scanned_at }.from(nil)
    end

    context "with filtering rule" do
      let(:screener) { create(:screener, user: user, rules: "master_instrument.ltp > 175") }

      before do
        allow($redis).to receive(:call).and_return(nil)
      end

      it "filters instruments based on rules" do
        result = screener.scan
        expect(result).to include(master_instrument2.id)
        expect(result).not_to include(master_instrument1.id)
      end
    end
  end

  describe "#scanned_master_instruments" do
    let(:screener) { create(:screener, :with_master_instrument) }
    let!(:master_instrument1) { create(:master_instrument, :with_upstox) }
    let!(:master_instrument2) { create(:master_instrument, :with_upstox) }

    before do
      screener.update(scanned_master_instrument_ids: [ master_instrument1.id ])
    end

    it "returns scanned master instruments" do
      expect(screener.scanned_master_instruments).to include(master_instrument1)
      expect(screener.scanned_master_instruments).not_to include(master_instrument2)
    end
  end

  describe "attr_accessor :master_instrument" do
    let(:screener) { create(:screener, :with_master_instrument) }
    let(:master_instrument) { create(:master_instrument) }

    it "can set and get master_instrument" do
      screener.master_instrument = master_instrument
      expect(screener.master_instrument).to eq(master_instrument)
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:screener, :with_master_instrument)).to be_valid
    end

    it "creates a valid screener" do
      expect(create(:screener, :with_master_instrument)).to be_persisted
    end

    it "creates inactive screener with trait" do
      screener = create(:screener, :with_master_instrument, :inactive)
      expect(screener.active).to be false
    end

    it "creates screener with complex rule using trait" do
      screener = create(:screener, :with_master_instrument, :with_complex_rule)
      expect(screener.rules).to include("ltp")
    end
  end
end

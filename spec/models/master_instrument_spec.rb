require 'rails_helper'

RSpec.describe MasterInstrument, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:zerodha_instrument).class_name("ZerodhaInstrument").optional }
    it { is_expected.to belong_to(:upstox_instrument).class_name("UpstoxInstrument").optional }
    it { is_expected.to have_many(:instrument_histories).dependent(:destroy) }
  end

  describe "attributes" do
    let(:master_instrument) { create(:master_instrument) }

    it "stores name" do
      expect(master_instrument.name).to be_present
    end

    it "stores exchange" do
      expect(master_instrument.exchange).to be_present
    end

    it "stores exchange_token" do
      expect(master_instrument.exchange_token).to be_present
    end
  end

  describe ".create_from_exchange_data" do
    context "with ZerodhaInstrument" do
      let(:zerodha_instrument) { create(:zerodha_instrument) }

      it "creates a new MasterInstrument" do
        expect {
          MasterInstrument.create_from_exchange_data(
            name: "Test Instrument",
            instrument: zerodha_instrument,
            exchange: "NSE",
            exchange_token: "12345"
          )
        }.to change(MasterInstrument, :count).by(1)
      end

      it "associates the zerodha_instrument" do
        master = MasterInstrument.create_from_exchange_data(
          name: "Test Instrument",
          instrument: zerodha_instrument,
          exchange: "NSE",
          exchange_token: "12345"
        )
        expect(master.zerodha_instrument).to eq(zerodha_instrument)
      end

      it "stores the exchange and exchange_token" do
        master = MasterInstrument.create_from_exchange_data(
          name: "Test Instrument",
          instrument: zerodha_instrument,
          exchange: "NSE",
          exchange_token: "12345"
        )
        expect(master.exchange).to eq("NSE")
        expect(master.exchange_token).to eq("12345")
      end

      it "stores the name" do
        master = MasterInstrument.create_from_exchange_data(
          name: "Test Instrument",
          instrument: zerodha_instrument,
          exchange: "NSE",
          exchange_token: "12345"
        )
        expect(master.name).to eq("Test Instrument")
      end
    end

    context "with UpstoxInstrument" do
      let(:upstox_instrument) { create(:upstox_instrument) }

      it "creates a new MasterInstrument" do
        expect {
          MasterInstrument.create_from_exchange_data(
            name: "Test Instrument",
            instrument: upstox_instrument,
            exchange: "NSE",
            exchange_token: "12345"
          )
        }.to change(MasterInstrument, :count).by(1)
      end

      it "associates the upstox_instrument" do
        master = MasterInstrument.create_from_exchange_data(
          name: "Test Instrument",
          instrument: upstox_instrument,
          exchange: "NSE",
          exchange_token: "12345"
        )
        expect(master.upstox_instrument).to eq(upstox_instrument)
      end
    end

    context "when record already exists" do
      let(:zerodha_instrument) { create(:zerodha_instrument) }
      let!(:existing_master) {
        MasterInstrument.create_from_exchange_data(
          name: "Original Name",
          instrument: zerodha_instrument,
          exchange: "NSE",
          exchange_token: "12345"
        )
      }

      it "does not create a duplicate record" do
        expect {
          MasterInstrument.create_from_exchange_data(
            name: "Updated Name",
            instrument: zerodha_instrument,
            exchange: "NSE",
            exchange_token: "12345"
          )
        }.not_to change(MasterInstrument, :count)
      end

      it "keeps the original name" do
        master = MasterInstrument.create_from_exchange_data(
          name: "Updated Name",
          instrument: zerodha_instrument,
          exchange: "NSE",
          exchange_token: "12345"
        )
        expect(master.name).to eq("Original Name")
      end
    end
  end

  describe "#ltp" do
    let(:master_instrument) { create(:master_instrument, exchange_token: "12345", ltp: 150.0) }

    context "when Redis has the LTP value" do
      before do
        allow(Redis.client).to receive(:call).with("GET", "12345").and_return("200.50")
      end

      it "returns the LTP from Redis" do
        expect(master_instrument.ltp).to eq(200.50)
      end
    end

    context "when Redis does not have the LTP value" do
      before do
        allow(Redis.client).to receive(:call).with("GET", "12345").and_return(nil)
      end

      it "returns the LTP from the database" do
        expect(master_instrument.ltp).to eq(150.0)
      end
    end

    context "when Redis returns empty string" do
      before do
        allow(Redis.client).to receive(:call).with("GET", "12345").and_return("")
      end

      it "returns the LTP from the database" do
        expect(master_instrument.ltp).to eq(150.0)
      end
    end
  end

  describe "dependent destroy" do
    let(:master_instrument) { create(:master_instrument) }

    it "destroys associated instrument_histories when destroyed" do
      create(:instrument_history, master_instrument: master_instrument)
      expect { master_instrument.destroy }.to change { InstrumentHistory.count }.by(-1)
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:master_instrument)).to be_valid
    end

    it "creates a valid master instrument" do
      expect(create(:master_instrument)).to be_persisted
    end

    it "creates with zerodha instrument using trait" do
      master = create(:master_instrument, :with_zerodha)
      expect(master.zerodha_instrument).to be_present
    end

    it "creates with upstox instrument using trait" do
      master = create(:master_instrument, :with_upstox)
      expect(master.upstox_instrument).to be_present
    end

    it "creates with both instruments using trait" do
      master = create(:master_instrument, :with_both)
      expect(master.zerodha_instrument).to be_present
      expect(master.upstox_instrument).to be_present
    end
  end
end

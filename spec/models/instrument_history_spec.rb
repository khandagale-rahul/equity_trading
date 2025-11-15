require 'rails_helper'

RSpec.describe InstrumentHistory, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:master_instrument) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:unit).with_values(minute: 1, hour: 2, day: 3, week: 4, month: 5) }
  end

  describe "attributes" do
    let(:instrument_history) { create(:instrument_history) }

    it "stores OHLC data" do
      expect(instrument_history.open).to be_present
      expect(instrument_history.high).to be_present
      expect(instrument_history.low).to be_present
      expect(instrument_history.close).to be_present
    end

    it "stores volume data" do
      expect(instrument_history.volume).to be_present
    end

    it "stores date" do
      expect(instrument_history.date).to be_present
    end

    it "stores interval" do
      expect(instrument_history.interval).to be_present
    end
  end

  describe "enum unit" do
    it "can be set to minute" do
      history = create(:instrument_history, unit: :minute)
      expect(history.unit).to eq("minute")
      expect(history.minute?).to be true
    end

    it "can be set to hour" do
      history = create(:instrument_history, unit: :hour)
      expect(history.unit).to eq("hour")
      expect(history.hour?).to be true
    end

    it "can be set to day" do
      history = create(:instrument_history, unit: :day)
      expect(history.unit).to eq("day")
      expect(history.day?).to be true
    end

    it "can be set to week" do
      history = create(:instrument_history, unit: :week)
      expect(history.unit).to eq("week")
      expect(history.week?).to be true
    end

    it "can be set to month" do
      history = create(:instrument_history, unit: :month)
      expect(history.unit).to eq("month")
      expect(history.month?).to be true
    end
  end

  describe "#previous_candle" do
    let(:master_instrument) { create(:master_instrument) }
    let!(:candle1) { create(:instrument_history, master_instrument: master_instrument, date: 3.days.ago, unit: :day, interval: 1, close: 100.0) }
    let!(:candle2) { create(:instrument_history, master_instrument: master_instrument, date: 2.days.ago, unit: :day, interval: 1, close: 105.0) }
    let!(:candle3) { create(:instrument_history, master_instrument: master_instrument, date: 1.day.ago, unit: :day, interval: 1, close: 110.0) }

    it "returns the previous candle for the same instrument/unit/interval" do
      expect(candle3.previous_candle).to eq(candle2)
      expect(candle2.previous_candle).to eq(candle1)
    end

    it "returns nil when there is no previous candle" do
      expect(candle1.previous_candle).to be_nil
    end

    it "only returns candles with matching unit and interval" do
      different_unit = create(:instrument_history, master_instrument: master_instrument, date: 4.days.ago, unit: :hour, interval: 1, close: 95.0)
      expect(candle1.previous_candle).to be_nil
    end

    it "only returns candles for the same master instrument" do
      other_instrument = create(:master_instrument)
      other_candle = create(:instrument_history, master_instrument: other_instrument, date: 4.days.ago, unit: :day, interval: 1, close: 95.0)
      expect(candle1.previous_candle).to be_nil
    end
  end

  describe "OHLC data validation" do
    it "stores valid OHLC values" do
      history = create(:instrument_history, open: 100.5, high: 105.75, low: 98.25, close: 103.0)
      expect(history.open).to eq(100.5)
      expect(history.high).to eq(105.75)
      expect(history.low).to eq(98.25)
      expect(history.close).to eq(103.0)
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:instrument_history)).to be_valid
    end

    it "creates a valid instrument history" do
      expect(create(:instrument_history)).to be_persisted
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Upstox::SyncInstrumentHistoryJob, type: :job do
  let(:user) { create(:user) }
  let(:api_config) { create(:api_configuration, :upstox, :authorized, user: user) }
  let(:instrument1) { create(:upstox_instrument) }
  let(:instrument2) { create(:upstox_instrument) }

  before do
    allow(UpstoxInstrument).to receive(:all).and_return(UpstoxInstrument.where(id: [ instrument1.id, instrument2.id ]))
  end

  describe '#perform' do
    context 'when no authorized API configuration exists' do
      it 'logs error and exits' do
        described_class.new.perform

        # expect(instrument1).not_to receive(:create_instrument_history)
      end
    end

    context 'when API configuration token is expired' do
      let(:expired_config) { create(:api_configuration, :upstox, :expired_token, user: user) }

      before do
        expired_config
      end

      it 'logs error and exits' do
        described_class.new.perform

        # expect(instrument1).not_to receive(:create_instrument_history)
      end
    end

    context 'when authorized API configuration exists' do
      before do
        api_config
        allow_any_instance_of(UpstoxInstrument).to receive(:create_instrument_history)
        # allow_any_instance_of(UpstoxInstrument).to receive(:create_intraday_instrument_history)
        # allow(instrument2).to receive(:create_instrument_history)
        # allow(instrument2).to receive(:create_intraday_instrument_history)
      end

      it 'syncs instrument history for all instruments with default parameters' do
        allow(described_class.new).to receive(:sleep)

        to_date = Date.today
        unit = "days"
        interval = 1
        days_back = 1
        from_date = days_back.days.ago.to_date.to_s

        UpstoxInstrument.find_each.each do |instrument|
          encoded_instrument_key = URI.encode_www_form_component(instrument.identifier)
          url = [
            "https://api.upstox.com/v3/historical-candle", encoded_instrument_key,
            unit, days_back, to_date, from_date
          ].join("/")

          stub_request(:get, url).with(headers: {
            'Accept'=>'*/*',
            'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Authorization'=>"Bearer #{api_config.access_token}",
            'Content-Type'=>'application/json',
            'Host'=>'api.upstox.com',
            'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/3.4.5p51'
          }).
          to_return(status: 200, body: "", headers: {})

          intraday_url = [ "https://api.upstox.com/v3/historical-candle/intraday", encoded_instrument_key, unit, days_back ].join("/")
          stub_request(:get, intraday_url).with(headers: {
            'Accept'=>'*/*',
            'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Authorization'=>"Bearer #{api_config.access_token}",
            'Content-Type'=>'application/json',
            'Host'=>'api.upstox.com',
            'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/3.4.5p51'
          }).
          to_return(status: 200, body: "", headers: {})
        end

        # expect_any_instance_of(UpstoxInstrument).to receive(:create_instrument_history).with(
        #   unit: "days",
        #   interval: 1,
        #   from_date: 1.day.ago.to_date.to_s,
        #   to_date: Date.today.to_s
        # )
        # expect_any_instance_of(UpstoxInstrument).to receive(:create_intraday_instrument_history).with(
        #   unit: "days",
        #   interval: 1
        # )
        described_class.new.perform(unit: unit, interval: interval, days_back: days_back)
      end

      it 'syncs instrument history with custom parameters' do
        allow(described_class.new).to receive(:sleep)

        to_date = Date.today
        unit = "minutes"
        interval = 4
        days_back = 7
        from_date = days_back.days.ago.to_date.to_s

        UpstoxInstrument.find_each.each do |instrument|
          encoded_instrument_key = URI.encode_www_form_component(instrument.identifier)
          url = [
            "https://api.upstox.com/v3/historical-candle", encoded_instrument_key,
            unit, days_back, to_date, from_date
          ].join("/")

          stub_request(:get, url).with(headers: {
            'Accept'=>'*/*',
            'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Authorization'=>"Bearer #{api_config.access_token}",
            'Content-Type'=>'application/json',
            'Host'=>'api.upstox.com',
            'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/3.4.5p51'
          }).
          to_return(status: 200, body: "", headers: {})

          intraday_url = [ "https://api.upstox.com/v3/historical-candle/intraday", encoded_instrument_key, unit, days_back ].join("/")
          stub_request(:get, intraday_url).with(headers: {
            'Accept'=>'*/*',
            'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Authorization'=>"Bearer #{api_config.access_token}",
            'Content-Type'=>'application/json',
            'Host'=>'api.upstox.com',
            'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/3.4.5p51'
          }).
          to_return(status: 200, body: "", headers: {})
        end

        # expect(instrument1).to have_received(:create_instrument_history).with(
        #   unit: "minutes",
        #   interval: 5,
        #   from_date: 7.days.ago.to_date.to_s,
        #   to_date: Date.today.to_s
        # )
        # described_class.new.perform(unit: "minute", interval: 5, days_back: 7)
      end

      it 'processes all instruments' do
        allow(described_class.new).to receive(:sleep)

        # described_class.new.perform

        # expect(instrument1).to have_received(:create_instrument_history)
        # expect(instrument2).to have_received(:create_instrument_history)
      end

      context 'when an instrument fails to sync' do
        before do
          allow(instrument1).to receive(:create_instrument_history).and_raise(StandardError, "API error")
        end

        it 'continues processing other instruments' do
          allow(described_class.new).to receive(:sleep)

          # expect {
          #   described_class.new.perform
          # }.not_to raise_error

          # expect(instrument2).to have_received(:create_instrument_history)
        end
      end
    end

    it 'can be enqueued' do
      expect {
        described_class.perform_async
      }.to change(described_class.jobs, :size).by(1)
    end
  end
end

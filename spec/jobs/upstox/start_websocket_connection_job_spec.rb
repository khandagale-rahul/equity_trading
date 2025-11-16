# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Upstox::StartWebsocketConnectionJob, type: :job do
  let(:user) { create(:user) }
  let(:api_config) { create(:api_configuration, :upstox, :authorized, user: user) }
  let(:redis_client) { Redis.client }
  let(:websocket_service) { instance_double(Upstox::WebsocketService) }

  before do
    allow(Redis).to receive(:client).and_return(redis_client)
    allow(redis_client).to receive(:call)
    allow(Upstox::WebsocketService).to receive(:new).and_return(websocket_service)
    allow(websocket_service).to receive(:on_message)
    allow(websocket_service).to receive(:on_error)
    allow(websocket_service).to receive(:on_connect)
    allow(websocket_service).to receive(:on_disconnect)
    allow(websocket_service).to receive(:connect)
    allow(websocket_service).to receive(:connected?).and_return(true)
    allow(websocket_service).to receive(:connection_stats).and_return({
      connected: true,
      subscriptions_count: 0,
      reconnect_attempts: 0,
      seconds_since_last_message: 0
    })
    allow(Thread).to receive(:new).and_yield
    allow(EM).to receive(:run).and_yield
    allow(EM).to receive(:add_timer).and_yield
    allow(EM).to receive(:add_periodic_timer)
    allow(EM).to receive(:cancel_timer)
    allow(UpstoxInstrument).to receive(:pluck).and_return({})
    allow(UpstoxInstrument).to receive(:where).and_return(double(pluck: []))
  end

  describe '#perform' do
    context 'when no authorized API configuration exists' do
      it 'logs error and sets Redis error status' do
        described_class.new.perform

        expect(redis_client).to have_received(:call).with("SET", "upstox:market_data:status", "error")
        expect(redis_client).to have_received(:call).with("SET", "upstox:market_data:error_message", "No authorized API configuration found")
      end
    end

    context 'when API configuration token is expired' do
      let(:expired_config) { create(:api_configuration, :upstox, :expired_token, user: user) }

      before do
        expired_config
      end

      it 'logs error and sets Redis error status' do
        described_class.new.perform

        expect(redis_client).to have_received(:call).with("SET", "upstox:market_data:status", "error")
        expect(redis_client).to have_received(:call).with("SET", "upstox:market_data:error_message", "Access token expired")
      end
    end

    context 'when authorized API configuration exists' do
      before do
        api_config
      end

      it 'sets Redis status to starting' do
        described_class.new.perform

        expect(redis_client).to have_received(:call).with("SET", "upstox:market_data:status", "starting")
      end

      it 'creates a WebSocket service instance' do
        described_class.new.perform

        expect(Upstox::WebsocketService).to have_received(:new).with(api_config.access_token)
      end

      it 'sets up message, error, connect, and disconnect handlers' do
        described_class.new.perform

        expect(websocket_service).to have_received(:on_message)
        expect(websocket_service).to have_received(:on_error)
        expect(websocket_service).to have_received(:on_connect)
        expect(websocket_service).to have_received(:on_disconnect)
      end
    end

    it 'can be enqueued' do
      expect {
        described_class.perform_async
      }.to change(described_class.jobs, :size).by(1)
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Upstox::StopWebsocketConnectionJob, type: :job do
  let(:redis_client) { instance_double(RedisClient) }
  let(:market_data_service) { instance_double(Upstox::WebsocketService) }

  before do
    allow(Redis).to receive(:client).and_return(redis_client)
    allow(redis_client).to receive(:call)
    allow(market_data_service).to receive(:disconnect)
  end

  describe '#perform' do
    it 'sets Redis status to stopping' do
      allow(redis_client).to receive(:call).with("GET", "upstox:market_data:status").and_return("stopped")

      described_class.new.perform

      expect(redis_client).to have_received(:call).with("SET", "upstox:market_data:status", "stopping")
    end

    context 'when service stops gracefully' do
      before do
        allow(redis_client).to receive(:call).with("GET", "upstox:market_data:status").and_return("stopped")
      end

      it 'cleans up Redis keys' do
        described_class.new.perform

        expect(redis_client).to have_received(:call).with("DEL", "upstox:market_data:status")
      end
    end

    context 'when service does not stop gracefully' do
      before do
        allow(redis_client).to receive(:call).with("GET", "upstox:market_data:status").and_return("running")
        allow(EM).to receive(:reactor_running?).and_return(false)
        $market_data_service = market_data_service
      end

      after do
        $market_data_service = nil
      end

      it 'forces stop and cleans up' do
        allow(described_class.new).to receive(:sleep)

        described_class.new.perform

        expect(market_data_service).to have_received(:disconnect)
        expect(redis_client).to have_received(:call).with("SET", "upstox:market_data:status", "stopped")
        expect(redis_client).to have_received(:call).with("DEL", "upstox:market_data:status")
      end
    end

    context 'when EventMachine reactor is running' do
      before do
        allow(redis_client).to receive(:call).with("GET", "upstox:market_data:status").and_return("running")
        allow(EM).to receive(:reactor_running?).and_return(true)
        allow(EM).to receive(:stop)
        allow(described_class.new).to receive(:sleep)
      end

      it 'stops the EventMachine reactor' do
        described_class.new.perform

        expect(EM).to have_received(:stop)
      end
    end

    it 'can be enqueued' do
      expect {
        described_class.perform_async
      }.to change(described_class.jobs, :size).by(1)
    end
  end
end

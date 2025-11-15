# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Upstox::HealthCheckWebsocketConnectionJob, type: :job do
  let(:redis_client) { instance_double(RedisClient) }
  let(:market_data_service) { instance_double(Upstox::WebsocketService) }

  before do
    allow(Redis).to receive(:client).and_return(redis_client)
    allow(redis_client).to receive(:call)
    allow(Upstox::StartWebsocketConnectionJob).to receive(:perform_async)
  end

  describe '#perform' do
    context 'outside trading hours' do
      it 'does not perform health check on weekends' do
        travel_to Time.zone.local(2025, 11, 16, 10, 0) # Sunday

        described_class.new.perform

        expect(redis_client).not_to have_received(:call)
      end

      it 'does not perform health check before 9 AM' do
        travel_to Time.zone.local(2025, 11, 17, 8, 30) # Monday 8:30 AM

        described_class.new.perform

        expect(redis_client).not_to have_received(:call)
      end

      it 'does not perform health check after 3:30 PM' do
        travel_to Time.zone.local(2025, 11, 17, 16, 0) # Monday 4:00 PM

        described_class.new.perform

        expect(redis_client).not_to have_received(:call)
      end
    end

    context 'during trading hours' do
      before do
        travel_to Time.zone.local(2025, 11, 17, 10, 0) # Monday 10:00 AM
      end

      context 'when service should be running but is not' do
        it 'restarts service when status is nil' do
          allow(redis_client).to receive(:call).with("GET", "upstox:market_data:status").and_return(nil, "running")
          allow(described_class.new).to receive(:sleep)

          described_class.new.perform

          expect(Upstox::StartWebsocketConnectionJob).to have_received(:perform_async)
        end

        it 'restarts service when status is stopped' do
          allow(redis_client).to receive(:call).with("GET", "upstox:market_data:status").and_return("stopped", "running")
          allow(described_class.new).to receive(:sleep)

          described_class.new.perform

          expect(Upstox::StartWebsocketConnectionJob).to have_received(:perform_async)
        end

        it 'restarts service when status is error' do
          allow(redis_client).to receive(:call).with("GET", "upstox:market_data:status").and_return("error", "running")
          allow(described_class.new).to receive(:sleep)

          described_class.new.perform

          expect(Upstox::StartWebsocketConnectionJob).to have_received(:perform_async)
        end
      end

      context 'when service status is running' do
        before do
          allow(redis_client).to receive(:call).with("GET", "upstox:market_data:status").and_return("running")
        end

        context 'and service instance does not exist' do
          it 'restarts the service' do
            $market_data_service = nil
            allow(described_class.new).to receive(:sleep)

            described_class.new.perform

            expect(Upstox::StartWebsocketConnectionJob).to have_received(:perform_async)
          end
        end

        context 'and service instance exists but is not connected' do
          before do
            $market_data_service = market_data_service
            allow(market_data_service).to receive(:connected?).and_return(false)
          end

          after do
            $market_data_service = nil
          end

          it 'checks reconnect attempts and restarts if >= 5' do
            connection_stats = { reconnect_attempts: 5 }
            allow(redis_client).to receive(:call).with("GET", "upstox:market_data:connection_stats")
                                                 .and_return(connection_stats.to_json)
            allow(redis_client).to receive(:call).with("GET", "upstox:market_data:status").and_return("running", "running")
            allow(described_class.new).to receive(:sleep)

            described_class.new.perform

            expect(Upstox::StartWebsocketConnectionJob).to have_received(:perform_async)
          end

          it 'does not restart if reconnect attempts < 5' do
            connection_stats = { reconnect_attempts: 2 }
            allow(redis_client).to receive(:call).with("GET", "upstox:market_data:connection_stats")
                                                 .and_return(connection_stats.to_json)

            described_class.new.perform

            expect(Upstox::StartWebsocketConnectionJob).not_to have_received(:perform_async)
          end
        end

        context 'and service instance is connected and healthy' do
          before do
            $market_data_service = market_data_service
            allow(market_data_service).to receive(:connected?).and_return(true)
            allow(market_data_service).to receive(:connection_stats).and_return({
              seconds_since_last_message: 60
            })
          end

          after do
            $market_data_service = nil
          end

          it 'does not restart the service' do
            described_class.new.perform

            expect(Upstox::StartWebsocketConnectionJob).not_to have_received(:perform_async)
          end
        end

        context 'and service has not received messages for > 300 seconds' do
          before do
            $market_data_service = market_data_service
            allow(market_data_service).to receive(:connected?).and_return(true)
            allow(market_data_service).to receive(:connection_stats).and_return({
              seconds_since_last_message: 350
            })
            allow(redis_client).to receive(:call).with("GET", "upstox:market_data:status").and_return("running", "running")
            allow(described_class.new).to receive(:sleep)
          end

          after do
            $market_data_service = nil
          end

          it 'restarts the service' do
            described_class.new.perform

            expect(Upstox::StartWebsocketConnectionJob).to have_received(:perform_async)
          end
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

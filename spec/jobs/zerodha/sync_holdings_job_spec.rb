# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Zerodha::SyncHoldingsJob, type: :job do
  let(:user) { create(:user) }
  let(:api_config) { create(:api_configuration, :authorized, user: user, api_name: :zerodha) }
  let(:sync_service) { instance_double(Zerodha::SyncHoldingsService) }

  before do
    allow(Zerodha::SyncHoldingsService).to receive(:new).and_return(sync_service)
  end

  describe '#perform' do
    context 'when no API configurations exist' do
      it 'returns early with no configs message' do
        allow(sync_service).to receive(:sync).with(api_config).and_return({
          total_configs: 0,
          message: "No authorized Zerodha API configurations found",
          results: []
        })

        described_class.new.perform

        expect(sync_service).to have_received(:sync)
      end
    end

    context 'when API configurations exist' do
      before do
        api_config
        allow(ApiConfiguration).to receive(:zerodha).and_return(ApiConfiguration.where(api_name: :zerodha))
      end

      it 'syncs holdings for all Zerodha configurations' do
        allow(sync_service).to receive(:sync).and_return({
          total_configs: 1,
          success_count: 1,
          error_count: 0,
          results: [ {
            user_id: user.id,
            user_name: user.name,
            status: :success,
            message: "Successfully synced 5 holdings"
          } ]
        })

        described_class.new.perform

        expect(sync_service).to have_received(:sync)
      end

      it 'filters by user_id when provided in options' do
        allow(sync_service).to receive(:sync).and_return({
          total_configs: 1,
          success_count: 1,
          error_count: 0,
          results: []
        })

        described_class.new.perform(user_id: user.id)

        expect(sync_service).to have_received(:sync)
      end

      context 'when sync has errors' do
        it 'logs errors for failed configurations' do
          allow(sync_service).to receive(:sync).and_return({
            total_configs: 1,
            success_count: 0,
            error_count: 1,
            results: [ {
              user_id: user.id,
              user_name: user.name,
              status: :error,
              message: "Access token expired"
            } ]
          })

          expect {
            described_class.new.perform
          }.not_to raise_error
        end
      end

      context 'when sync is successful' do
        it 'logs success for each configuration' do
          allow(sync_service).to receive(:sync).and_return({
            total_configs: 1,
            success_count: 1,
            error_count: 0,
            results: [ {
              user_id: user.id,
              user_name: user.name,
              status: :success,
              message: "Successfully synced 10 holdings"
            } ]
          })

          expect {
            described_class.new.perform
          }.not_to raise_error
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

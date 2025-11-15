# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScheduleStrategyExecutionJob, type: :job do
  let(:user) { create(:user) }

  describe '#perform' do
    context 'when no deployed strategies exist' do
      it 'completes without enqueuing any jobs' do
        described_class.new.perform

        expect(ScanEntryRuleJob.jobs.size).to eq(0)
      end
    end

    context 'when deployed strategies exist' do
      let!(:rule_based_strategy) do
        create(:strategy, :deployed, user: user, type: 'RuleBasedStrategy')
      end

      it 'enqueues ScanEntryRuleJob for RuleBasedStrategy' do
        described_class.new.perform

        expect(ScanEntryRuleJob.jobs.size).to eq(1)
        job = ScanEntryRuleJob.jobs.last
        expect(job['args']).to eq([ rule_based_strategy.id ])
      end

      context 'with ScreenerBasedStrategy' do
        let(:screener) { create(:screener, :with_master_instrument, user: user, active: true) }
        let!(:screener_based_strategy) do
          create(:screener_based_strategy, :deployed, user: user, screener_id: screener.id)
        end

        before do
          # Mock the screener_execution_time method
          allow_any_instance_of(ScreenerBasedStrategy).to receive(:screener_execution_time).and_return("10:30")
          allow_any_instance_of(ScreenerBasedStrategy).to receive(:reset_fields!)
        end

        it 'schedules ScanEntryRuleJob at the screener execution time' do
          travel_to Time.zone.local(2025, 11, 17, 9, 15) do
            described_class.new.perform

            expect(ScanEntryRuleJob.jobs.size).to eq(2) # rule_based + screener_based

            # Find the screener-based strategy job
            screener_job = ScanEntryRuleJob.jobs.find do |job|
              job['args'][0] == screener_based_strategy.id
            end

            expect(screener_job).not_to be_nil
            expect(screener_job['args'][1]).to eq({ "scanner_check" => true }.to_json)
          end
        end

        it 'calls reset_fields! on ScreenerBasedStrategy' do
          expect_any_instance_of(ScreenerBasedStrategy).to receive(:reset_fields!)

          described_class.new.perform
        end
      end

      context 'with InstrumentBasedStrategy' do
        let(:master_instrument) { create(:master_instrument) }
        let!(:instrument_based_strategy) do
          create(:instrument_based_strategy, :deployed, user: user, master_instrument_ids: [ master_instrument.id ])
        end

        it 'enqueues ScanEntryRuleJob for InstrumentBasedStrategy' do
          described_class.new.perform

          expect(ScanEntryRuleJob.jobs.size).to eq(2) # rule_based + instrument_based

          # Find the instrument-based strategy job
          instrument_job = ScanEntryRuleJob.jobs.find do |job|
            job['args'][0] == instrument_based_strategy.id
          end

          expect(instrument_job).not_to be_nil
        end
      end

      context 'with multiple deployed strategies' do
        let!(:strategy2) { create(:strategy, :deployed, user: user, type: 'RuleBasedStrategy') }
        let!(:strategy3) { create(:strategy, :deployed, user: user, type: 'RuleBasedStrategy') }

        it 'enqueues jobs for all deployed strategies' do
          described_class.new.perform

          expect(ScanEntryRuleJob.jobs.size).to eq(3)
        end
      end

      context 'with non-deployed strategies' do
        let!(:non_deployed_strategy) { create(:strategy, user: user, deployed: false) }

        it 'only enqueues jobs for deployed strategies' do
          described_class.new.perform

          expect(ScanEntryRuleJob.jobs.size).to eq(1)
          job = ScanEntryRuleJob.jobs.last
          expect(job['args'][0]).to eq(rule_based_strategy.id)
        end
      end
    end

    context 'when an error occurs' do
      before do
        allow(Strategy).to receive(:deployed).and_raise(StandardError, "Database error")
      end

      it 'logs error and re-raises the exception' do
        expect {
          described_class.new.perform
        }.to raise_error(StandardError, "Database error")
      end
    end

    it 'can be enqueued' do
      expect {
        described_class.perform_async
      }.to change(described_class.jobs, :size).by(1)
    end
  end
end

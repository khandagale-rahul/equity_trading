# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScanEntryRuleJob, type: :job do
  let(:user) { create(:user) }
  let(:master_instrument) { create(:master_instrument) }
  let(:strategy) { create(:strategy, :deployed, user: user, master_instrument_ids: [ master_instrument.id ]) }

  describe '#perform' do
    context 'when strategy is not found' do
      it 'logs warning and exits' do
        described_class.new.perform(999999)

        # Should not raise error, just exit gracefully
        expect(ScanEntryRuleJob.jobs.size).to eq(0)
      end
    end

    context 'when strategy exists' do
      before do
        allow_any_instance_of(Strategy).to receive(:evaluate_entry_rule) do |&block|
          block.call([]) if block
          []
        end
      end

      it 'parses options from JSON string' do
        expect {
          described_class.new.perform(strategy.id, { scanner_check: true }.to_json)
        }.not_to raise_error
      end

      context 'with ScreenerBasedStrategy and scanner_check option' do
        let(:screener) { create(:screener, :with_master_instrument, user: user, active: true) }
        let(:screener_strategy) { create(:screener_based_strategy, :deployed, user: user, screener_id: screener.id) }

        before do
          allow_any_instance_of(ScreenerBasedStrategy).to receive(:scan)
          allow_any_instance_of(ScreenerBasedStrategy).to receive(:evaluate_entry_rule) do |&block|
            block.call([]) if block
            []
          end
        end

        it 'runs screener scan when scanner_check is true' do
          expect_any_instance_of(ScreenerBasedStrategy).to receive(:scan)

          described_class.new.perform(screener_strategy.id, { scanner_check: true }.to_json)
        end

        it 'does not run screener scan when scanner_check is false' do
          expect_any_instance_of(ScreenerBasedStrategy).not_to receive(:scan)

          described_class.new.perform(screener_strategy.id, { scanner_check: false }.to_json)
        end
      end

      context 'when daily max entries is reached' do
        before do
          strategy.update(
            daily_max_entries: 2,
            entered_master_instrument_ids: [ 1, 2 ]
          )
        end

        it 'resets entered_master_instrument_ids and exits' do
          described_class.new.perform(strategy.id)

          strategy.reload
          expect(strategy.entered_master_instrument_ids).to eq([])
          expect(ScanEntryRuleJob.jobs.size).to eq(0)
        end
      end

      context 'when instruments have reached re-enter limit' do
        let(:master_instrument2) { create(:master_instrument) }

        before do
          strategy.update(
            re_enter: 2,
            master_instrument_ids: [ master_instrument.id, master_instrument2.id ],
            entered_master_instrument_ids: [ master_instrument.id, master_instrument.id ]
          )
          allow_any_instance_of(Strategy).to receive(:evaluate_entry_rule).with([ master_instrument2.id ]) do |&block|
            block.call([]) if block
            []
          end
        end

        it 'filters out instruments that reached re-enter limit' do
          expect_any_instance_of(Strategy).to receive(:evaluate_entry_rule).with([ master_instrument2.id ]) do |&block|
            block.call([]) if block
            []
          end
          described_class.new.perform(strategy.id)
        end
      end

      context 'when no candidate instruments available' do
        before do
          strategy.update(master_instrument_ids: [])
          allow_any_instance_of(Strategy).to receive(:evaluate_entry_rule)
        end

        it 'exits without evaluating rules' do
          expect_any_instance_of(Strategy).not_to receive(:evaluate_entry_rule)
          described_class.new.perform(strategy.id)
        end
      end

      context 'when entry rule matches instruments' do
        let(:master_instrument2) { create(:master_instrument) }

        before do
          strategy.update(master_instrument_ids: [ master_instrument.id, master_instrument2.id ])
          allow_any_instance_of(Strategy).to receive(:evaluate_entry_rule) do |&block|
            block.call([ master_instrument.id ]) if block
            [ master_instrument.id ]
          end
          allow_any_instance_of(Strategy).to receive(:initiate_place_order)
        end

        it 'adds matched instruments to entered_master_instrument_ids' do
          described_class.new.perform(strategy.id)

          strategy.reload
          expect(strategy.entered_master_instrument_ids).to include(master_instrument.id)
        end

        it 'initiates order placement for matched instruments' do
          expect_any_instance_of(Strategy).to receive(:initiate_place_order).with(master_instrument.id)

          described_class.new.perform(strategy.id)
        end

        it 'schedules next job execution in 1 minute' do
          travel_to Time.zone.local(2025, 11, 17, 10, 30, 45) do
            described_class.new.perform(strategy.id)

            expect(ScanEntryRuleJob.jobs.size).to eq(1)
            job = ScanEntryRuleJob.jobs.last
            expect(job['args']).to eq([ strategy.id, { "scanner_check" => false }.to_json ])
          end
        end

        context 'when strategy fails to save' do
          before do
            allow_any_instance_of(Strategy).to receive(:save).and_return(false)
            allow_any_instance_of(Strategy).to receive_message_chain(:errors, :full_messages).and_return([ "Validation error" ])
          end

          it 'logs error but continues processing' do
            expect {
              described_class.new.perform(strategy.id)
            }.not_to raise_error
          end
        end
      end

      context 'when entry rule does not match any instruments' do
        before do
          allow_any_instance_of(Strategy).to receive(:evaluate_entry_rule) do |&block|
            block.call([]) if block
            []
          end
        end

        it 'does not initiate any orders' do
          expect_any_instance_of(Strategy).not_to receive(:initiate_place_order)

          described_class.new.perform(strategy.id)
        end

        it 'still schedules next job execution' do
          described_class.new.perform(strategy.id)

          expect(ScanEntryRuleJob.jobs.size).to eq(1)
        end
      end
    end

    context 'when an error occurs during execution' do
      before do
        allow_any_instance_of(Strategy).to receive(:evaluate_entry_rule).and_raise(StandardError, "Rule evaluation error")
      end

      it 'logs error and handles gracefully' do
        expect {
          described_class.new.perform(strategy.id)
        }.not_to raise_error
      end
    end

    it 'can be enqueued' do
      expect {
        described_class.perform_async(strategy.id)
      }.to change(described_class.jobs, :size).by(1)
    end
  end
end

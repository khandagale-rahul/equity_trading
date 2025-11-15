# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScanExitRuleJob, type: :job do
  let(:user) { create(:user) }
  let(:master_instrument) { create(:master_instrument) }
  let(:strategy) { create(:strategy, :deployed, user: user, master_instrument_ids: [ master_instrument.id ]) }
  let(:entry_order) { create(:zerodha_order, user: user, strategy: strategy, master_instrument: master_instrument, trade_action: :entry) }

  describe '#perform' do
    context 'when entry order is not found' do
      it 'logs warning and exits gracefully' do
        expect {
          described_class.new.perform(999999)
        }.not_to raise_error
      end
    end

    context 'when entry order exists' do
      context 'and exit order is completed' do
        let(:exit_order) do
          create(:zerodha_order, user: user, strategy: strategy, master_instrument: master_instrument,
                 trade_action: :exit, entry_order_id: entry_order.id)
        end

        before do
          allow(exit_order).to receive(:completed?).and_return(true)
          allow(entry_order).to receive(:exit_order).and_return(exit_order)
          allow_any_instance_of(Strategy).to receive(:evaluate_exit_rule).with([ exit_order.master_instrument_id ]).and_return([])
        end

        it 'logs warning and terminates' do
          expect_any_instance_of(Strategy).not_to receive(:evaluate_exit_rule).with([ exit_order.master_instrument_id ])
          described_class.new.perform(entry_order.id)
        end
      end

      context 'and exit order is cancelled' do
        let(:exit_order) do
          create(:zerodha_order, user: user, strategy: strategy, master_instrument: master_instrument,
                 trade_action: :exit, entry_order_id: entry_order.id)
        end

        before do
          allow(exit_order).to receive(:cancelled?).and_return(true)
          allow(exit_order).to receive(:completed?).and_return(false)
          allow(entry_order).to receive(:exit_order).and_return(exit_order)
          allow_any_instance_of(Strategy).to receive(:evaluate_exit_rule).with([ exit_order.master_instrument_id ]).and_return([])
        end

        it 'logs warning and terminates' do
          expect_any_instance_of(Strategy).not_to receive(:evaluate_exit_rule).with([ exit_order.master_instrument_id ])
          described_class.new.perform(entry_order.id)
        end
      end

      context 'when exit order does not exist' do
        before do
          allow(entry_order).to receive(:exit_order).and_return(nil)
          allow(entry_order).to receive(:initiate_exit_order).and_return(double(save: true, strategy: strategy, master_instrument_id: master_instrument.id))
          allow(strategy).to receive(:evaluate_exit_rule).and_return([])
        end

        it 'creates exit order' do
          expect_any_instance_of(ZerodhaOrder).to receive(:initiate_exit_order)
          described_class.new.perform(entry_order.id)
        end
      end

      context 'when exit order exists and is not completed or cancelled' do
        let(:exit_order) do
          create(:zerodha_order, user: user, strategy: strategy, master_instrument: master_instrument,
                 trade_action: :exit, entry_order_id: entry_order.id)
        end

        before do
          allow(entry_order).to receive(:exit_order).and_return(exit_order)
          allow(entry_order).to receive(:completed?).and_return(false)
          allow(entry_order).to receive(:update_order_status)
          allow(Order).to receive(:find_by).with(id: entry_order.id).and_return(entry_order)
          allow_any_instance_of(ZerodhaOrder).to receive(:exit_order).and_return(exit_order)
          allow(exit_order).to receive(:completed?).and_return(false)
          allow(exit_order).to receive(:cancelled?).and_return(false)
          allow(exit_order).to receive(:undiscarded?).and_return(true)
          allow(exit_order).to receive(:update_order_status)
          allow(exit_order).to receive(:exit_at_current_price)
          allow(strategy).to receive(:evaluate_exit_rule).and_return([])
        end

        it 'updates entry order status when not completed' do
          expect(entry_order).to receive(:update_order_status)

          described_class.new.perform(entry_order.id)
        end

        it 'updates exit order status' do
          expect(exit_order).to receive(:update_order_status)

          described_class.new.perform(entry_order.id)
        end

        it 'does not update entry order status when already completed' do
          allow(entry_order).to receive(:completed?).and_return(true)

          expect(entry_order).not_to receive(:update_order_status)

          described_class.new.perform(entry_order.id)
        end

        context 'when exit rule is satisfied' do
          before do
            allow(strategy).to receive(:evaluate_exit_rule).with([ master_instrument.id ]).and_return([ master_instrument.id ])
          end

          it 'exits at current price' do
            expect(exit_order).to receive(:exit_at_current_price)

            described_class.new.perform(entry_order.id)
          end

          it 'does not reschedule the job' do
            described_class.clear
            described_class.new.perform(entry_order.id)
            expect(ScanExitRuleJob.jobs.size).to eq(0)
          end
        end

        context 'when exit rule is not satisfied' do
          before do
            allow(strategy).to receive(:evaluate_exit_rule).with([ master_instrument.id ]).and_return([])
          end

          it 'does not exit at current price' do
            expect(exit_order).not_to receive(:exit_at_current_price)

            described_class.new.perform(entry_order.id)
          end

          it 'reschedules the job in 1 minute' do
            described_class.clear
            travel_to Time.zone.local(2025, 11, 17, 10, 30, 45) do
              described_class.new.perform(entry_order.id)

              expect(ScanExitRuleJob.jobs.size).to eq(1)
              job = ScanExitRuleJob.jobs.last
              expect(job['args']).to eq([ entry_order.id ])
            end
          end
        end
      end
    end

    context 'when an error occurs during execution' do
      before do
        allow(Order).to receive(:entry).and_raise(StandardError, "Database error")
      end

      it 'logs error and handles gracefully' do
        expect {
          described_class.new.perform(entry_order.id)
        }.not_to raise_error
      end
    end

    it 'can be enqueued' do
      entry_order
      described_class.clear
      expect {
        described_class.perform_async(entry_order.id)
      }.to change(described_class.jobs, :size).by(1)
    end

    it 'uses unique job lock to prevent duplicates' do
      # This tests the sidekiq_options configuration
      expect(described_class.get_sidekiq_options['lock']).to eq(:until_executed)
      expect(described_class.get_sidekiq_options['on_conflict']).to eq(:reject)
    end
  end
end

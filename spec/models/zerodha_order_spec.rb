require 'rails_helper'

RSpec.describe ZerodhaOrder, type: :model do
  describe "inheritance" do
    it "inherits from Order" do
      expect(ZerodhaOrder.superclass).to eq(Order)
    end
  end

  describe "constants" do
    it "defines PRODUCT constants" do
      expect(ZerodhaOrder::PRODUCT_MIS).to eq("MIS")
      expect(ZerodhaOrder::PRODUCT_CNC).to eq("CNC")
      expect(ZerodhaOrder::PRODUCT_NRML).to eq("NRML")
      expect(ZerodhaOrder::PRODUCT_CO).to eq("CO")
    end

    it "defines ORDER_TYPE constants" do
      expect(ZerodhaOrder::ORDER_TYPE_MARKET).to eq("MARKET")
      expect(ZerodhaOrder::ORDER_TYPE_LIMIT).to eq("LIMIT")
      expect(ZerodhaOrder::ORDER_TYPE_SLM).to eq("SL-M")
      expect(ZerodhaOrder::ORDER_TYPE_SL).to eq("SL")
    end

    it "defines VARIETY constants" do
      expect(ZerodhaOrder::VARIETY_REGULAR).to eq("regular")
      expect(ZerodhaOrder::VARIETY_CO).to eq("co")
      expect(ZerodhaOrder::VARIETY_AMO).to eq("amo")
    end

    it "defines TRANSACTION_TYPE constants" do
      expect(ZerodhaOrder::TRANSACTION_TYPE_BUY).to eq("BUY")
      expect(ZerodhaOrder::TRANSACTION_TYPE_SELL).to eq("SELL")
    end

    it "defines VALIDITY constants" do
      expect(ZerodhaOrder::VALIDITY_DAY).to eq("DAY")
      expect(ZerodhaOrder::VALIDITY_IOC).to eq("IOC")
      expect(ZerodhaOrder::VALIDITY_TTL).to eq("TTL")
    end
  end

  describe "AASM states" do
    let(:zerodha_order) { build(:zerodha_order) }

    it "has all required states" do
      expect(ZerodhaOrder.aasm.states.map(&:name)).to include(
        :completed, :rejected, :cancelled, :open, :trigger_pending,
        :modify_pending_at_exchange, :cancellation_pending_at_exchange,
        :pending_at_exchange, :unknown
      )
    end
  end

  describe "#map_zerodha_status" do
    let(:zerodha_order) { build(:zerodha_order) }

    it "maps COMPLETE to completed" do
      expect(zerodha_order.send(:map_zerodha_status, "COMPLETE")).to eq("completed")
    end

    it "maps REJECTED to rejected" do
      expect(zerodha_order.send(:map_zerodha_status, "REJECTED")).to eq("rejected")
    end

    it "maps CANCELLED to cancelled" do
      expect(zerodha_order.send(:map_zerodha_status, "CANCELLED")).to eq("cancelled")
    end

    it "maps OPEN to open" do
      expect(zerodha_order.send(:map_zerodha_status, "OPEN")).to eq("open")
    end

    it "maps TRIGGER PENDING to trigger_pending" do
      expect(zerodha_order.send(:map_zerodha_status, "TRIGGER PENDING")).to eq("trigger_pending")
    end

    it "maps unknown status to unknown" do
      expect(zerodha_order.send(:map_zerodha_status, "UNKNOWN_STATUS")).to eq("unknown")
    end

    it "handles lowercase status" do
      expect(zerodha_order.send(:map_zerodha_status, "complete")).to eq("completed")
    end
  end

  describe "#opposite_transaction_type" do
    it "returns SELL for BUY transaction" do
      order = build(:zerodha_order, transaction_type: ZerodhaOrder::TRANSACTION_TYPE_BUY)
      expect(order.send(:opposite_transaction_type)).to eq(ZerodhaOrder::TRANSACTION_TYPE_SELL)
    end

    it "returns BUY for SELL transaction" do
      order = build(:zerodha_order, transaction_type: ZerodhaOrder::TRANSACTION_TYPE_SELL)
      expect(order.send(:opposite_transaction_type)).to eq(ZerodhaOrder::TRANSACTION_TYPE_BUY)
    end
  end

  describe "#update_order_details" do
    let(:zerodha_order) { create(:zerodha_order) }
    let(:order_history) do
      {
        status: "COMPLETE",
        status_message: "Order completed",
        status_message_raw: "Success",
        order_timestamp: "2025-01-15 10:30:00",
        exchange_update_timestamp: "2025-01-15 10:30:05",
        exchange_timestamp: "2025-01-15 10:30:10",
        price: 100.0,
        trigger_price: 0,
        average_price: 100.5,
        quantity: 1,
        disclosed_quantity: 0,
        filled_quantity: 1,
        pending_quantity: 0,
        cancelled_quantity: 0,
        meta: {},
        guid: "test-guid-123"
      }
    end

    it "updates order with history data" do
      zerodha_order.update_order_details(order_history)
      zerodha_order.reload

      expect(zerodha_order.status).to eq("COMPLETE")
      expect(zerodha_order.aasm_state).to eq("completed")
      expect(zerodha_order.status_message).to eq("Order completed")
      expect(zerodha_order.average_price).to eq(100.5)
      expect(zerodha_order.filled_quantity).to eq(1)
      expect(zerodha_order.guid).to eq("test-guid-123")
    end
  end

  describe "STI type" do
    let(:zerodha_order) { create(:zerodha_order) }

    it "has type set to ZerodhaOrder" do
      expect(zerodha_order.type).to eq("ZerodhaOrder")
    end

    it "is queryable using STI" do
      create(:zerodha_order)
      expect(ZerodhaOrder.count).to eq(1)
      expect(Order.count).to eq(1)
    end
  end

  describe "factory" do
    it "has a valid factory" do
      expect(build(:zerodha_order)).to be_valid
    end

    it "creates a valid zerodha order" do
      expect(create(:zerodha_order)).to be_persisted
    end

    it "creates entry order with trait" do
      order = create(:zerodha_order, :entry)
      expect(order.entry?).to be true
      expect(order.transaction_type).to eq(ZerodhaOrder::TRANSACTION_TYPE_BUY)
    end

    it "creates exit order with trait" do
      order = create(:zerodha_order, :exit)
      expect(order.exit?).to be true
      expect(order.transaction_type).to eq(ZerodhaOrder::TRANSACTION_TYPE_SELL)
    end

    it "creates limit order with trait" do
      order = create(:zerodha_order, :limit_order)
      expect(order.order_type).to eq(ZerodhaOrder::ORDER_TYPE_LIMIT)
    end

    it "creates stop loss order with trait" do
      order = create(:zerodha_order, :stop_loss)
      expect(order.order_type).to eq(ZerodhaOrder::ORDER_TYPE_SL)
      expect(order.trigger_price).to be_present
    end
  end
end

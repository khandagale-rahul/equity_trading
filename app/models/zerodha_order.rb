class ZerodhaOrder < Order
  PRODUCT_MIS = "MIS"
  PRODUCT_CNC = "CNC"
  PRODUCT_NRML = "NRML"
  PRODUCT_CO = "CO"

  # Order types
  ORDER_TYPE_MARKET = "MARKET"
  ORDER_TYPE_LIMIT = "LIMIT"
  ORDER_TYPE_SLM = "SL-M"
  ORDER_TYPE_SL = "SL"

  # Varities
  VARIETY_REGULAR = "regular"
  VARIETY_CO = "co"
  VARIETY_AMO = "amo"

  # Transaction type
  TRANSACTION_TYPE_BUY = "BUY"
  TRANSACTION_TYPE_SELL = "SELL"

  # Validity
  VALIDITY_DAY = "DAY"
  VALIDITY_IOC = "IOC"
  VALIDITY_TTL = "TTL"

  before_create :set_instrument
  before_create :set_order_fields

  after_commit :notify_about_initiation, on: :create
  after_commit :push_to_broker, on: :create

  def exit_at_current_price
    return if status.eql?("COMPLETE") || status.include?("CANCELLED")

    ltp = master_instrument.ltp
    zerodha_instrument = master_instrument.zerodha_instrument

    buffer = zerodha_instrument.tick_size * 2
    new_price = transaction_type.eql?(ZerodhaOrder::TRANSACTION_TYPE_SELL) ? (ltp - buffer) : (ltp + buffer)
    new_price = new_price <= 0 ? 1.0 : new_price

    params = {
      price: new_price,
      trigger_price: 0,
      order_type: ZerodhaOrder::ORDER_TYPE_LIMIT
    }
    modify_order(params)
  end

  def initiate_exit_order
    return unless entry?

    entry_price = placed_order.average_price.to_f > 0 ? placed_order.average_price : placed_order.price
    initial_stop_loss = entry_price * 0.01
    trigger_price = entry_price.round - initial_stop_loss
    sl_price = trigger_price - trigger_price * 0.07

    self.build_exit_order(
      user_id: user_id,
      strategy_id: strategy_id,
      master_instrument_id: master_instrument_id,
      type: "ZerodhaOrder",
      tradingsymbol: tradingsymbol,
      exchange: exchange,
      variety: variety,
      order_type: ZerodhaOrder::ORDER_TYPE_SL,
      product: product,
      validity: ZerodhaOrder::VALIDITY_DAY,
      transaction_type: opposite_transaction_type,
      quantity: filled_quantity,
      price: sl_price.round,
      trigger_price: trigger_price.round
    )
  end

  private

  def opposite_transaction_type
    transaction_type.eql?(ZerodhaOrder::TRANSACTION_TYPE_SELL) ? ZerodhaOrder::TRANSACTION_TYPE_BUY : ZerodhaOrder::TRANSACTION_TYPE_SELL
  end

  def set_instrument
    self.instrument = master_instrument.zerodha_instrument
  end

  def set_order_fields
    return nil if instrument.blank?

    ltp = master_instrument.ltp
    self.tradingsymbol = instrument.identifier
    self.exchange = instrument.exchange
    self.variety = ZerodhaOrder::VARIETY_REGULAR
    self.order_type = ZerodhaOrder::ORDER_TYPE_SL
    self.product = ZerodhaOrder::PRODUCT_MIS
    self.validity = ZerodhaOrder::VALIDITY_IOC
    self.transaction_type = ZerodhaOrder::TRANSACTION_TYPE_BUY
    self.quantity = 1
    self.trigger_price = ltp + instrument.tick_size
    self.price = ltp + instrument.tick_size
    self.disclosed_quantity = nil
    self.expiry = instrument.expiry
    self.instrument_token = instrument.instrument_token
    self.quote_price = ltp
  end

  def push_to_broker
    super && return if strategy.only_simulate

    params = {
      variety: variety,
      exchange: exchange,
      tradingsymbol: tradingsymbol,
      transaction_type: transaction_type,
      quantity: quantity,
      product: product,
      order_type: order_type,
      price: price,
      validity: validity,
      validity_ttl: validity_ttl,
      trigger_price: trigger_price
    }

    api_service = Zerodha::ApiService.new
    order_response = api_service.place_order(params.compact)
    handle_response(order_response)
  end

  def handle_response(create_order_response)
    if create_order_response["status"] == "success"
      self.update(
        broker_order_id: create_order_response.dig("data", "order_id")
      )
    elsif create_order_response["status"] == "error"
      self.update(
        status: create_order_response["status"],
        status_message: create_order_response["message"],
        status_message_raw: create_order_response["error_type"]
      )
    end
  end

  def notify_about_initiation
    super && return if strategy.only_simulate

    messages = []
    messages << "Placing Zerodha Order. Entry Price: #{price}"

    self.push_notifications.create(
      user_id: user_id,
      message: message.join(" ")
    )
  end

  def modify_order(params)
    super && return if strategy.only_simulate

    params = params.merge({ variety: self.variety, order_id: self.broker_order_id })

    api_service = Zerodha::ApiService.new
    response = api_service.modify_order(params.compact)

    if response["status"].eql?("error")
      if response["message"].downcase.include?("maximum allowed order modifications exceeded")
        cancel_and_reinitiate_trailing
      end
    end

    response
  end

  def cancel_and_reinitiate_trailing
    if self.update_order_charges && !self.cancelled?
      self.cancel_order

      reinitiate_trailing
    end
  end

  def cancel_order
    params = { variety: self.variety, order_id: self.broker_order_id }

    api_service = Zerodha::ApiService.new
    api_service.cancel_order(params)
    update_order_status

    api_service.response
  end

  def update_order_status
    order_history = getOrderHistory

    if order_history["status"] == "success"
      last_status = order_history["data"].last

      self.update_order_details(last_status)
    end
  end

  def update_order_details(last_order_history)
    self.reload.update(
      status: last_order_history["status"],
      status_message: last_order_history["status_message"],
      status_message_raw: last_order_history["status_message_raw"],
      order_timestamp: last_order_history["order_timestamp"],
      instrument_token: last_order_history["instrument_token"],
      exchange_update_timestamp: last_order_history["exchange_update_timestamp"],
      exchange_timestamp: last_order_history["exchange_timestamp"],
      price: last_order_history["price"],
      trigger_price: last_order_history["trigger_price"],
      average_price: last_order_history["average_price"],
      quantity: last_order_history["quantity"],
      filled_quantity: last_order_history["filled_quantity"],
      pending_quantity: last_order_history["pending_quantity"],
      cancelled_quantity: last_order_history["cancelled_quantity"],
      meta: last_order_history["meta"],
      guid: last_order_history["guid"],
      order_type: last_order_history["order_type"]
    )
  end

  def getOrderHistory
    api_service = Zerodha::ApiService.new
    api_service.get_order_detail(broker_order_id)
  end

  def reinitiate_trailing
    self.update_order_charges
    sleep 1

    if self.cancelled?
      self.discard
      ScanExitRuleJob.perform_async(entry_order_id)
    end
  end
end

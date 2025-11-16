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

  before_create :set_entry_order_fields, if: -> { entry? }

  after_commit :notify_about_initiation, on: :create
  after_commit :push_to_broker, on: :create
  after_commit :handle_postback_entry_order_update

  def initiate_exit_order
    return unless entry?

    entry_price = average_price.to_f > 0 ? average_price : price
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

  def update_order_details(last_order_history)
    last_order_history = last_order_history.with_indifferent_access

    self.reload.update(
      status: last_order_history[:status],
      aasm_state: map_zerodha_status(last_order_history[:status]),
      status_message: last_order_history[:status_message],
      status_message_raw: last_order_history[:status_message_raw],
      order_timestamp: parse_timestamp(last_order_history[:order_timestamp]),
      exchange_update_timestamp: parse_timestamp(last_order_history[:exchange_update_timestamp]),
      exchange_timestamp: parse_timestamp(last_order_history[:exchange_timestamp]),
      price: last_order_history[:price],
      trigger_price: last_order_history[:trigger_price],
      average_price: last_order_history[:average_price],
      quantity: last_order_history[:quantity],
      disclosed_quantity: last_order_history[:disclosed_quantity],
      filled_quantity: last_order_history[:filled_quantity],
      pending_quantity: last_order_history[:pending_quantity],
      cancelled_quantity: last_order_history[:cancelled_quantity],
      meta: last_order_history[:meta],
      guid: last_order_history[:guid]
    )
  end

  def handle_postback_entry_order_update
    return unless entry?

    if previous_changes.include?(:filled_quantity)
      if filled_quantity_previously_was.nil?
        ScanExitRuleJob.perform_async(id)
      else
        params = { quantity: filled_quantity.to_i }
        exit_order.modify_order(params)
      end
    end
  end

  def update_order_status
    order_history = getOrderHistory

    if order_history["status"] == "success"
      last_status = order_history["data"].last

      self.update_order_details(last_status)
    end
  end

  def exit_at_current_price
    return if entry? || completed? || cancelled?

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

  private

  def api_service_instance
    @api_config ||= strategy.user.api_configurations.zerodha.last
    return unless @api_config

    @api_service ||= Zerodha::ApiService.new(api_key: @api_config.api_key, access_token: @api_config.access_token)
  end

  def map_zerodha_status(zerodha_status)
    case zerodha_status&.upcase
    when "COMPLETE"
      "completed"
    when "REJECTED"
      "rejected"
    when "CANCELLED"
      "cancelled"
    when "OPEN"
      "open"
    when "TRIGGER PENDING"
      "trigger_pending"
    when "MODIFY PENDING"
      "modify_pending_at_exchange"
    when "CANCEL PENDING"
      "cancellation_pending_at_exchange"
    when "OPEN PENDING"
      "pending_at_exchange"
    else
      "unknown"
    end
  end

  def opposite_transaction_type
    transaction_type.eql?(ZerodhaOrder::TRANSACTION_TYPE_SELL) ? ZerodhaOrder::TRANSACTION_TYPE_BUY : ZerodhaOrder::TRANSACTION_TYPE_SELL
  end

  def set_entry_order_fields
    self.instrument = master_instrument.zerodha_instrument
    ltp = master_instrument.ltp

    return unless instrument

    self.assign_attributes(
      tradingsymbol: instrument.symbol,
      exchange: instrument.exchange,
      variety: (variety.presence || ZerodhaOrder::VARIETY_REGULAR),
      order_type: (order_type.presence || ZerodhaOrder::ORDER_TYPE_SL),
      product: (product.presence || ZerodhaOrder::PRODUCT_MIS),
      validity: (validity.presence || ZerodhaOrder::VALIDITY_IOC),
      transaction_type: (transaction_type.presence || ZerodhaOrder::TRANSACTION_TYPE_BUY),
      quantity: 1,
      trigger_price: (ltp + instrument.tick_size),
      price: (ltp + instrument.tick_size),
      disclosed_quantity: nil,
      quote_ltp: ltp
    )
  end

  def push_to_broker
    return super if strategy.only_simulate
    return handle_missing_configuration unless api_service_instance.present?

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
    api_service_instance.place_order(params.compact)
    handle_response(api_service_instance.response)
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
    elsif create_order_response["status"] == "failed"
      parsed_response = JSON.parse(create_order_response["message"])
      self.update(
        status: parsed_response["status"],
        status_message: parsed_response["message"],
        status_message_raw: parsed_response["error_type"]
      )
    end
  end

  def notify_about_initiation
    return super if strategy.only_simulate

    messages = []
    messages << "Placing Zerodha Order. Entry Price: #{price}"

    self.push_notifications.create(
      user_id: user_id,
      message: messages.join(" ")
    )
  end

  def modify_order(params)
    return super if strategy.only_simulate
    return handle_missing_configuration unless api_service_instance

    params = params.merge({ variety: self.variety, order_id: self.broker_order_id })

    api_service_instance.modify_order(params.compact)
    response = api_service_instance.response

    if response["status"].eql?("error")
      if response["message"].downcase.include?("maximum allowed order modifications exceeded")
        cancel_and_re_initiate_trailing
      end
    end

    response
  end

  def cancel_and_re_initiate_trailing
    if self.update_order_charges && !self.cancelled?
      self.cancel_order

      re_initiate_trailing
    end
  end

  def cancel_order
    return handle_missing_configuration unless api_service_instance
    params = { variety: self.variety, order_id: self.broker_order_id }

    api_service_instance.cancel_order(params)
    update_order_status

    api_service_instance.response
  end

  def getOrderHistory
    return handle_missing_configuration unless api_service_instance

    api_service_instance.get_order_detail(broker_order_id)
    api_service_instance.response
  end

  def re_initiate_trailing
    self.update_order_charges

    if self.cancelled?
      self.discard
      ScanExitRuleJob.perform_async(entry_order_id)
    end
  end
end

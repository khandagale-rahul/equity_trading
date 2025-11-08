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
  after_commit :handle_simulation, on: :create

  private

  def set_instrument
    self.instrument = master_instrument.zerodha_instrument
  end

  def set_order_fields
    return nil if instrument.blank?

    ltp = master_instrument.ltp
    self.tradingsymbol = instrument.identifier
    self.exchange = instrument.exchange
    self.variety = ZerodhaOrder::VARIETY_REGULAR
    self.order_type = Order::ORDER_TYPE_SL
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
    return if strategy.only_simulate

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
    messages = []
    messages << strategy.only_simulate ? "Simulating" : "Placing"
    messages << "Zerodha Order. Entry Price: #{price}"

    self.push_notifications.create(
      user_id: user_id,
      message: message.join(" ")
    )
  end
end

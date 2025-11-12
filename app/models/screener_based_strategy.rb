class ScreenerBasedStrategy < Strategy
  validate :validate_screener
  validate :validate_screener_execution_time

  [
    :screener_id,
    :screener_execution_time
  ].each do |param|
    define_method(param) do
      parameters[param.to_s]
    end

    define_method("#{param}=") do |value|
      self.parameters ||= {}
      self.parameters[param.to_s] = value
    end
  end

  def screener
    Screener.find_by(id: screener_id)
  end

  def scan
    return unless screener.present?

    self.master_instrument_ids = screener.scan
    self.save
  end

  def reset_fields!
    update(master_instrument_ids: [], entered_master_instrument_ids: [], close_order_ids: [])
  end

  private
    def validate_screener
      unless screener_id.present?
        errors.add(:screener_id, "must be present")
      end

      unless screener_execution_time.present?
        errors.add(:screener_execution_time, "must be present")
      end
    end

    def validate_screener_execution_time
      if screener_execution_time.blank?
        errors.add(:screener_execution_time, "must be present")
      elsif screener_execution_time !~ /\A([01]\d|2[0-3]):([0-5]\d)\z/
        errors.add(:screener_execution_time, "is not valid")
      end
    end
end

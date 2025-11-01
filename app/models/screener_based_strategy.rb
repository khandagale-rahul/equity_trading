class ScreenerBasedStrategy < Strategy
  def screener_id
    parameters["screener_id"]
  end

  def screener_id=(id)
    self.parameters = { screener_id: id }
  end

  def screener
    Screener.find_by(id: screener_id)
  end
end

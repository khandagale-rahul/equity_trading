class RuleBasedStrategy < Strategy
  def rules
    parameters["rules"]
  end

  def rules=(value)
    self.parameters = { rules: value }
  end
end

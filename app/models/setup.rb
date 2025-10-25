class Setup < ApplicationRecord
  belongs_to :user

  def evaluate_rule(master_instrument)
    return unless rules.present?

    Thread.current[:dentaku_context] = {}
    Thread.current[:dentaku_context][:instrument] = master_instrument

    CALCULATOR.evaluate(rules)
  end
end

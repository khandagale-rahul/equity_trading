class Setup < ApplicationRecord
  include SetupConcern

  belongs_to :user

  attr_accessor :instrument

  def evaluate_rule(master_instrument)
    result = nil
    ActiveRecord::Base.transaction do
      begin
        return unless rules.present?

        self.instrument = master_instrument
        result = eval(rules)
      rescue
        errors.add(:rules, "is invalid")
      end
      raise ActiveRecord::Rollback
    end

    result
  end
end

class Strategy < ApplicationRecord
  include StrategyConcern
  include RuleEvaluationConcern

  attr_accessor :master_instrument

  belongs_to :user

  validates :entry_rule,
            :exit_rule,
            presence: true
  validate :validate_entry_rule
  validate :validate_exit_rule

  def master_instruments
    MasterInstrument.where(id: master_instrument_ids)
  end

  def evaluate_entry_rule(market_data)
    filtered_master_instrument_ids = []

    ActiveRecord::Base.transaction(requires_new: true) do
      master_instruments.find_each(batch_size: 100) do |master_instrument|
        break if self.errors.present?

        if evaluate_rule(:entry_rule, master_instrument)
          filtered_master_instrument_ids << master_instrument.id
        end
      end
      raise ActiveRecord::Rollback
    end
  end

  def evaluate_exit_rule(market_data)
    filtered_master_instrument_ids = []

    ActiveRecord::Base.transaction(requires_new: true) do
      master_instruments.find_each(batch_size: 100) do |master_instrument|
        break if self.errors.present?

        if evaluate_rule(:exit_rule, master_instrument)
          filtered_master_instrument_ids << master_instrument.id
        end
      end
      raise ActiveRecord::Rollback
    end
  end

  private
    def validate_entry_rule
      validate_rules_syntax(:entry_rule)
      return if self.errors.present?

      ActiveRecord::Base.transaction(requires_new: true) do
        begin
          evaluate_rule(:entry_rule, MasterInstrument.first)
        rescue
        end
        raise ActiveRecord::Rollback
      end
    end

    def validate_exit_rule
      validate_rules_syntax(:exit_rule)
      return if self.errors.present?

      ActiveRecord::Base.transaction(requires_new: true) do
        begin
          evaluate_rule(:exit_rule, MasterInstrument.first)
        rescue
        end
        raise ActiveRecord::Rollback
      end
    end

    def validate_rules_syntax(rule_type)
      DANGEROUS_PATTERNS.each do |pattern|
        if send(rule_type).match?(pattern)
          errors.add(rule_type, "contains potentially dangerous code pattern")
          return
        end
      end
    end

    def evaluate_rule(rule_type, master_instrument)
      result = nil
      @calculated_data = {}

      begin
        self.master_instrument = master_instrument
        result = eval(send(rule_type).squish)
      rescue
        errors.add(rule_type, "is invalid")
      end

      result
    end
end

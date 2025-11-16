class Strategy < ApplicationRecord
  has_paper_trail

  include StrategyConcern
  include RuleEvaluationConcern

  attr_accessor :master_instrument

  belongs_to :user

  has_many :push_notifications, as: :item

  validates :entry_rule,
            :exit_rule,
            presence: true
  validate :validate_entry_rule
  validate :validate_exit_rule

  scope :deployed, -> { where(deployed: true) }

  def master_instruments(instruments_ids = self.master_instrument_ids)
    MasterInstrument.where(id: instruments_ids)
  end

  def evaluate_entry_rule(instruments_ids = self.master_instrument_ids, &block)
    filtered_master_instrument_ids = []

    ActiveRecord::Base.transaction(requires_new: true) do
      master_instruments(instruments_ids).find_each(batch_size: 100) do |master_instrument|
        break if self.errors.present?

        if evaluate_rule(:entry_rule, master_instrument)
          filtered_master_instrument_ids << master_instrument.id
        end
      end
      raise ActiveRecord::Rollback
    end

    if block
      block.call(filtered_master_instrument_ids)
    else
      filtered_master_instrument_ids
    end
  end

  def evaluate_exit_rule(instruments_ids = self.master_instrument_ids)
    filtered_master_instrument_ids = []

    ActiveRecord::Base.transaction(requires_new: true) do
      master_instruments(instruments_ids).find_each(batch_size: 100) do |master_instrument|
        break if self.errors.present?

        if evaluate_rule(:exit_rule, master_instrument)
          filtered_master_instrument_ids << master_instrument.id
        end
      end
      raise ActiveRecord::Rollback
    end

    filtered_master_instrument_ids
  end

  def initiate_place_order(master_instrument_id)
    broker_klass.entry.create(
      strategy_id: id,
      user_id: user.id,
      master_instrument_id: master_instrument_id
    )
  end

  private
    def broker_klass
      ZerodhaOrder
    end

    def validate_entry_rule
      return unless changes.include?("entry_rule")

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
      return unless changes.include?("exit_rule")

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
        result = instance_eval(send(rule_type).squish)
      rescue SyntaxError, StandardError => e
        errors.add(rule_type, "is invalid")
      end

      result
    end
end

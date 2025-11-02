class Screener < ApplicationRecord
  include ScreenerConcern
  include RuleEvaluationConcern

  attr_accessor :master_instrument

  belongs_to :user
  validates :name,
            :rules,
            presence: true

  validate :validate_rules_syntax

  def scan
    filtered_master_instrument_ids = []

    ActiveRecord::Base.transaction(requires_new: true) do
      MasterInstrument.joins(:upstox_instrument).find_each(batch_size: 100) do |master_instrument|
        break if self.errors.present?

        if evaluate_rule(master_instrument)
          filtered_master_instrument_ids << master_instrument.id
        end
      end
      raise ActiveRecord::Rollback
    end

    self.update(
      scanned_master_instrument_ids: filtered_master_instrument_ids,
      scanned_at: Time.current
    )
    filtered_master_instrument_ids
  end

  def scanned_master_instruments
    MasterInstrument.where(id: scanned_master_instrument_ids)
  end

  private

    def validate_rules_syntax
      return unless changes.include?("rules")
      return unless rules.present?

      DANGEROUS_PATTERNS.each do |pattern|
        if rules.match?(pattern)
          errors.add(:rules, "contains potentially dangerous code pattern")
          return
        end
      end

      ActiveRecord::Base.transaction(requires_new: true) do
        MasterInstrument.joins(:upstox_instrument).find_each(batch_size: 100) do |master_instrument|
          break if self.errors.present?

          evaluate_rule(master_instrument)
        end
        raise ActiveRecord::Rollback
      end
    end

    def evaluate_rule(master_instrument)
      result = nil
      @calculated_data = {}

      begin
        return unless rules.present?

        self.master_instrument = master_instrument
        result = eval(rules.squish)
      rescue
        errors.add(:rules, "is invalid")
      end

      result
    end
end

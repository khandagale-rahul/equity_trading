class Screener < ApplicationRecord
  include ScreenerConcern

  belongs_to :user

  attr_accessor :master_instrument

  def scan
    filtered_master_instrument_ids = []

    ActiveRecord::Base.transaction do
      MasterInstrument.joins(:upstox_instrument).find_each(batch_size: 100) do |master_instrument|
        if evaluate_rule(master_instrument)
          filtered_master_instrument_ids << master_instrument.id
        end
      end
      raise ActiveRecord::Rollback
    end

    self.update(scanned_instrument_ids: filtered_master_instrument_ids)
    filtered_master_instrument_ids
  end

  def master_instruments
    MasterInstrument.joins(:upstox_instrument).where(id: scanned_instrument_ids).order(
      Arel.sql("
        CASE
          WHEN ltp IS NULL OR previous_day_ltp IS NULL OR previous_day_ltp = 0 THEN NULL
          ELSE ((ltp - previous_day_ltp) / previous_day_ltp) * 100
        END desc NULLS LAST
      ")
    )
  end

  private

    def evaluate_rule(master_instrument)
      result = nil
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

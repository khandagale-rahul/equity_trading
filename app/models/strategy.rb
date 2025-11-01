class Strategy < ApplicationRecord
  belongs_to :user

  def instrument_ids=(ids)
    return {} unless instrument_based?

    self.parameters = { instrument_ids: ids }
  end
end

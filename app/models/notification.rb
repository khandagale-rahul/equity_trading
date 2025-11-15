class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :item, polymorphic: true

  include AASM
  aasm column: :status do
    state :sent, initial: true
    state :delivered, :read

    event :deliver do
      transitions from: :sent, to: :delivered
    end

    event :read do
      transitions from: :delivered, to: :read
    end
  end
end

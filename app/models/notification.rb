class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :item, polymorphic: true

  include AASM
  aasm do
    state :sent, initial: true
    state :delivered, :read
  end
end

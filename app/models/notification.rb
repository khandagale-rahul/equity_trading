class Notification < ApplicationRecord
  include AASM

  belongs_to :user
  belongs_to :item, polymorphic: true

  aasm do
    state :sent, initial: true
    state :delived, :read
  end
end

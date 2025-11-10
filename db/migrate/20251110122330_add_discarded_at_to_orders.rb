class AddDiscardedAtToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :discarded_at, :datetime
    add_index :orders, :discarded_at
  end
end

class AddCloseOrderIdsToStrategy < ActiveRecord::Migration[8.0]
  def change
    add_column :strategies, :close_order_ids, :integer, array: true, default: []
  end
end

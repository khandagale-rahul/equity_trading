class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :strategy, null: false, foreign_key: true
      t.references :master_instrument, null: false, foreign_key: true
      t.string :type
      t.integer :instrument_id
      t.string :instrument_type
      t.integer :trade_action
      t.string :broker_order_id
      t.string :status
      t.text :status_message
      t.text :status_message_raw
      t.string :tradingsymbol
      t.string :exchange
      t.datetime :exchange_update_timestamp
      t.datetime :exchange_timestamp
      t.string :variety
      t.string :order_type
      t.datetime :order_timestamp
      t.string :product
      t.string :validity
      t.integer :validity_ttl
      t.string :transaction_type
      t.integer :quantity
      t.integer :disclosed_quantity
      t.float :quote_ltp
      t.float :price
      t.float :trigger_price
      t.float :average_price
      t.integer :filled_quantity
      t.integer :pending_quantity
      t.integer :cancelled_quantity
      t.json :meta
      t.string :guid
      t.integer :entry_order_id

      t.timestamps
    end
  end
end

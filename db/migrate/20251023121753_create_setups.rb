class CreateSetups < ActiveRecord::Migration[8.0]
  def change
    create_table :setups do |t|
      t.string :name
      t.references :user, null: false, foreign_key: true
      t.jsonb :shortlisted_instruments, default: {}
      t.integer :executed_instrument_ids, array: true, default: []
      t.boolean :active, default: false
      t.integer :trades_per_day, default: 0
      t.text :rules

      t.timestamps
    end
  end
end

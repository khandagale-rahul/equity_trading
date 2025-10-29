class CreateScreeners < ActiveRecord::Migration[8.0]
  def change
    create_table :screeners do |t|
      t.string :name
      t.references :user, null: false, foreign_key: true
      t.boolean :active, default: true
      t.text :rules
      t.integer :scanned_instrument_ids, array: true, default: []

      t.timestamps
    end
  end
end

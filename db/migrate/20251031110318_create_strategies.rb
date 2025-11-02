class CreateStrategies < ActiveRecord::Migration[8.0]
  def change
    create_table :strategies do |t|
      t.string :name
      t.string :type, null: false
      t.references :user, null: false, foreign_key: true
      t.integer :master_instrument_ids, array: true, default: []
      t.jsonb :parameters, default: {}
      t.text :description
      t.text :entry_rule
      t.text :exit_rule

      t.timestamps
    end
  end
end

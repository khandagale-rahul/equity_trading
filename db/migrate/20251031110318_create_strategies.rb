class CreateStrategies < ActiveRecord::Migration[8.0]
  def change
    create_table :strategies do |t|
      t.string :name
      t.string :type, null: false
      t.references :user, null: false, foreign_key: true
      t.jsonb :parameters, default: {}
      t.text :description

      t.timestamps
    end
  end
end

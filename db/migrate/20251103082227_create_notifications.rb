class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.string :type, null: false
      t.references :user, null: false, foreign_key: true
      t.references :item, polymorphic: true, null: false
      t.jsonb :data

      t.timestamps
    end
  end
end

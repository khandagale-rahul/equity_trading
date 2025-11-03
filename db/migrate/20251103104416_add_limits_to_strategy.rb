class AddLimitsToStrategy < ActiveRecord::Migration[8.0]
  def change
    add_column :strategies, :re_enter, :integer, default: 0, null: false
    add_column :strategies, :daily_max_entries, :integer, default: 5, null: false
  end
end

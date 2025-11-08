class AddOnlySimulateToStrategy < ActiveRecord::Migration[8.0]
  def change
    add_column :strategies, :only_simulate, :boolean, default: false
  end
end

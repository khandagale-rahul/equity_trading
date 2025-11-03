class AddDeployedToStrategies < ActiveRecord::Migration[8.0]
  def change
    add_column :strategies, :deployed, :boolean, default: false, null: false
  end
end

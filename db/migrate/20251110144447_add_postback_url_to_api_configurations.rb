class AddPostbackUrlToApiConfigurations < ActiveRecord::Migration[8.0]
  def change
    add_column :api_configurations, :postback_url, :string
  end
end

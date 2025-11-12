class AddAasmStateToNotifications < ActiveRecord::Migration[8.0]
  def change
    add_column :notifications, :aasm_state, :string
  end
end

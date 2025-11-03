class AddEnteredExistedMasterInstrumentIdsToStrategy < ActiveRecord::Migration[8.0]
  def change
    add_column :strategies, :entered_master_instrument_ids, :integer, array: true, default: []
    add_column :strategies, :existed_master_instrument_ids, :integer, array: true, default: []
  end
end

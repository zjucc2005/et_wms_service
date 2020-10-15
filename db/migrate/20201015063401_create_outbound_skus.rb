class CreateOutboundSkus < ActiveRecord::Migration[5.1]

  def change
    create_table :outbound_skus do |t|
      t.references :account
      t.references :outbound_order
      t.string :depot_code
      t.string :sku_code
      t.string :barcode
      t.string :name
      t.string :foreign_name
      t.integer :quantity
      t.jsonb :operate_infos

      t.timestamps :null => false
    end
  end

end

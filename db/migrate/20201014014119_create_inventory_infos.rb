class CreateInventoryInfos < ActiveRecord::Migration[5.1]

  def change
    create_table :inventory_infos do |t|
      t.references :account
      t.references :inventory
      t.string :batch_num
      t.string :status
      t.string :sku_code
      t.string :barcode
      t.integer :quantity, :default => 0
      t.integer :available_quantity, :default => 0
      t.integer :frozen_quantity, :default => 0
      t.string :shelf_num
      t.string :depot_code
      t.datetime :production_date
      t.datetime :expiry_date
      t.string :country_of_origin

      t.timestamps :null => false
    end
  end

end

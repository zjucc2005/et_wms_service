class CreateInventories < ActiveRecord::Migration[5.1]

  def change
    create_table :inventories do |t|
      t.references :account
      t.string :channel
      t.string :sku_code
      t.string :barcode
      t.integer :quantity, :default => 0
      t.integer :available_quantity, :default => 0
      t.integer :frozen_quantity, :default => 0
      t.string :name
      t.string :foreign_name
      t.string :abc_category
      t.integer :caution_threshold

      t.timestamps :null => false
    end
  end

end

class CreateProducts < ActiveRecord::Migration[5.1]

  def change
    create_table :products do |t|
      t.references :account
      t.references :product_category
      t.references :service_category
      t.string :channel
      t.string :sku_code
      t.string :barcode
      t.string :name
      t.string :foreign_name
      t.string :description

      t.timestamps :null => false
    end
  end

end

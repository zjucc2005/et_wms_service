class CreateProductSalesProperties < ActiveRecord::Migration[5.1]

  def change
    create_table :product_sales_properties do |t|
      t.references :product
      t.string :brand
      t.string :model
      t.decimal :price, :precision => 10, :scale => 2
      t.string :currency
      t.decimal :weight, :precision => 8, :scale => 2
      t.jsonb :clearance_attributes, :default => {}
      t.string :thumbnail

      t.timestamps :null => false
    end
  end

end

class CreateInboundSkus < ActiveRecord::Migration[5.1]

  def change
    create_table :inbound_skus do |t|
      t.references :account
      t.references :inbound_notification
      t.string :status
      t.string :sku_code
      t.string :barcode
      t.integer :quantity
      t.datetime :production_date
      t.datetime :expiry_date
      t.string :country_of_origin
      t.string :abc_category
      t.string :name
      t.string :foreign_name

      t.timestamps :null => false
    end
  end

end

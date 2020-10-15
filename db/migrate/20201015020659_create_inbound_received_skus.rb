class CreateInboundReceivedSkus < ActiveRecord::Migration[5.1]

  def change
    create_table :inbound_received_skus do |t|
      t.references :inbound_received_info
      t.references :inbound_sku
      t.integer :quantity
    end
  end

end
